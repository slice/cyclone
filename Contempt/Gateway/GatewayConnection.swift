import FineJSON
import Foundation
import Network
import NWWebSocket
import os
import RichJSONParser

/// A connection to the Discord gateway.
public class GatewayConnection {
  /// The WebSocket connection to the gateway.
  private var socket: NWWebSocket?

  /// The disguise used in this gateway connection.
  private let disguise: Disguise

  /// The latest sequence number received from the gateway.
  private(set) var sequence: Int?

  private var log: Logger

  public var delegate: GatewayConnectionDelegate?

  /// The dispatch queue for handling Discord gateway messages.
  private var dispatchQueue =
    DispatchQueue(label: "contempt-gateway-connection")

  /// The timer used to manage periodic heartbeating.
  private var heartbeatTimer: DispatchSourceTimer!

  /// The Discord user token to `IDENTIFY` to the gateway with.
  private var token: String

  /// Initializes a new Discord gateway connection with a certain user token and
  /// disguise.
  init(token: String, disguise: Disguise) {
    self.token = token
    self.disguise = disguise
    self.log = Logger(subsystem: "zone.slice.Contempt", category: "gateway")
  }

  /// Connect to the Discord gateway.
  public func connect(
    toGateway gatewayURL: URL,
    fromDiscordEndpoint endpoint: URL
  ) {
    let options = NWWebSocket.defaultOptions

    // Last update: 2021-11-11
    options.setAdditionalHeaders([
      ("Accept-Encoding", "gzip, deflate, br"),
      ("Accept-Language", self.disguise.systemLocale),
      ("Cache-Control", "no-cache"),
      ("Connection", "Upgrade"),
      ("Host", gatewayURL.host!),
      ("Origin", endpoint.absoluteString),
      ("Pragma", "no-cache"),
      ("User-Agent", self.disguise.userAgent),
    ])

    let socket = NWWebSocket(
      url: gatewayURL,
      connectAutomatically: false,
      options: options,
      connectionQueue: self.dispatchQueue
    )
    self.socket = socket
    socket.delegate = self

    self.log.info("connecting to \(gatewayURL)...")

    socket.connect()
  }

  /// Disconnect from the Discord gateway.
  public func disconnect(withCloseCode closeCode: NWProtocolWebSocket
    .CloseCode = .protocolCode(.normalClosure))
  {
    guard let socket = self.socket else {
      preconditionFailure("already disconnected")
    }

    socket.disconnect(closeCode: closeCode)
  }

  /// Encodes a JSON payload and sends it through the gateway socket.
  public func send(json: JSON) {
    guard let socket = self.socket else {
      preconditionFailure("cannot send JSON when not connected")
    }

    let encoder = FineJSONEncoder()
    encoder.optionalEncodingStrategy = .explicitNull
    encoder.jsonSerializeOptions = JSONSerializeOptions(isPrettyPrint: false)
    guard let data = try? encoder.encode(json) else {
      fatalError("failed to encode JSON data to send")
    }

    self.log.info("<- \(String(data: data, encoding: .utf8)!)")
    socket.send(data: data)
  }

  /// Sends a single heartbeat to the Discord gateway.
  public func heartbeat() {
    self.send(json: .object(.init([
      "op": .number(String(Opcode.heartbeat.rawValue)),
      "d": .number(String(self.sequence ?? 0)),
    ])))
  }

  /// Begin heartbeating at a fixed interval.
  func beginHeartbeating(every interval: DispatchTimeInterval) {
    self.heartbeatTimer = DispatchSource
      .makeTimerSource(queue: self.dispatchQueue)

    self.heartbeatTimer.setEventHandler { [weak self] in
      guard let self = self else { return }
      self.heartbeat()
    }

    self.heartbeatTimer.schedule(
      deadline: .now().advanced(by: interval),
      repeating: interval
    )

    self.heartbeatTimer.resume()
  }

  /// `IDENTIFY` to the Discord gateway.
  public func identify() {
    // Last update: 2021-11-11
    let identifyPayload: JSON = .object(.init([
      "d": .object(.init([
        "capabilities": .number(String(self.disguise.capabilities)),
        "client_state": .object(.init([
          "guild_hashes": .object(.init()),
          "highest_last_message_id": .string("0"),
          "read_state_version": .number("0"),
          "user_guild_settings_version": .number("-1"),
          "user_settings_version": .number("-1"),
        ])),
        // TODO(skip): Implement compression.
        "compress": .boolean(false),
        "presence": .object(.init([
          "activities": .array([]),
          "afk": .boolean(false),
          "since": .number("0"),
          "status": .string("online"),
        ])),
        "properties": self.disguise.superPropertiesJSON(),
        "token": .string(self.token),
      ])),
      "op": .number(String(Opcode.identify.rawValue)),
    ]))
    self.send(json: identifyPayload)
  }
}

// MARK: WebSocketConnectionDelegate

extension GatewayConnection: WebSocketConnectionDelegate {
  public func webSocketDidDisconnect(
    connection _: WebSocketConnection,
    closeCode: NWProtocolWebSocket.CloseCode,
    reason _: Data?
  ) {
    var closeCodeValue: UInt16?
    switch closeCode {
    case let .protocolCode(definedCloseCode):
      closeCodeValue = definedCloseCode.rawValue
    case let .applicationCode(value):
      closeCodeValue = value
    case let .privateCode(value):
      closeCodeValue = value
    @unknown default:
      break
    }

    if let closeCodeValue = closeCodeValue {
      self.log.info("disconnected (close code: \(closeCodeValue))")
    } else {
      self.log.info("disconnected (unknown close code)")
    }
  }

  public func webSocketViabilityDidChange(
    connection _: WebSocketConnection,
    isViable _: Bool
  ) {}

  public func webSocketDidAttemptBetterPathMigration(
    result _: Result<WebSocketConnection,
      NWError>
  ) {}

  public func webSocketDidReceiveError(
    connection _: WebSocketConnection,
    error: NWError
  ) {
    self.log
      .error(
        "errored: \(error.localizedDescription), \(error.debugDescription)"
      )
  }

  public func webSocketDidReceivePong(connection _: WebSocketConnection) {}

  public func webSocketDidReceiveMessage(
    connection _: WebSocketConnection,
    string text: String
  ) {
    self.log.info("-> \(text)")
    self.handlePacket(ofJSON: text)
  }

  public func webSocketDidReceiveMessage(
    connection _: WebSocketConnection,
    data _: Data
  ) {
    self.log.info("-> <binary>")
  }

  public func webSocketDidConnect(connection _: WebSocketConnection) {
    self.log.info("connected")
  }
}

// MARK: Packet Handling

extension GatewayConnection {
  private func handleDispatchPacket(_ packet: GatewayPacket<Any>) {
    self.delegate?.gatewaySentDispatchPacket(packet)
  }

  /// Handle a single packet encoded in JSON from the Discord gateway.
  func handlePacket(ofJSON packet: String) {
    let packetEncoded = packet.data(using: .utf8)!

    let decodedPacket = try! JSONSerialization
      .jsonObject(with: packetEncoded) as! [String: Any]

    let eventName = decodedPacket["t"] as? String
    let sequence = decodedPacket["s"] as? Int
    let data = decodedPacket["d"] as? [String: Any]
    let opcode = Opcode(rawValue: decodedPacket["op"] as! Int)!

    self.log
      .debug(
        "t:\(String(describing: eventName)), s:\(String(describing: sequence)), op:\(opcode.rawValue)"
      )

    if let sequence = sequence {
      self.sequence = sequence
    }

    switch opcode {
    case .dispatch:
      let packet = GatewayPacket<Any>(
        op: opcode,
        data: data as Any,
        sequence: sequence,
        eventName: eventName
      )
      self.handleDispatchPacket(packet)
    case .hello:
      let heartbeatInterval = data?["heartbeat_interval"] as! Int
      self.delegate?
        .gatewaySentHello(heartbeatInterval: Double(heartbeatInterval) / 1000)
      self.beginHeartbeating(every: .milliseconds(heartbeatInterval))
      self.identify()
    case .heartbeat:
      self.heartbeat()
    default:
      break
    }
  }
}
