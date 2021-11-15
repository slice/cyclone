import Combine
import FineJSON
import Foundation
import Network
import os
import RichJSONParser

/// A connection to the Discord gateway.
public class GatewayConnection {
  /// The WebSocket connection to the gateway.
  private var socket: WebSocket?

  /// The disguise used in this gateway connection.
  private let disguise: Disguise

  /// The latest sequence number received from the gateway.
  private(set) var sequence: Int?

  private var log: Logger

  /// The dispatch queue for handling Discord gateway messages.
  private var dispatchQueue =
    DispatchQueue(label: "contempt-gateway-connection")

  /// The timer used to manage periodic heartbeating.
  private var heartbeatTimer: AnyCancellable?

  /// The Combine subscriber used to handle incoming WebSocket events.
  private var eventHandler: AnyCancellable?

  /// The Discord user token to `IDENTIFY` to the gateway with.
  private var token: String

  /// A Combine subject for incoming gateway packets.
  public private(set) var packets = PassthroughSubject<GatewayPacket<Any>,
    Never>()

  deinit {
    heartbeatTimer = nil
  }

  /// Initializes a new Discord gateway connection with a certain user token and
  /// disguise.
  init(token: String, disguise: Disguise) {
    self.token = token
    self.disguise = disguise
    log = Logger(subsystem: "zone.slice.Contempt", category: "gateway")
  }

  /// Connect to the Discord gateway.
  public func connect(
    toGateway gatewayURL: URL,
    fromDiscordEndpoint endpoint: URL
  ) {
    // Last update: 2021-11-11
    let additionalHeaders = [
      ("Accept-Encoding", "gzip, deflate, br"),
      ("Accept-Language", disguise.systemLocale),
      ("Cache-Control", "no-cache"),
      ("Host", gatewayURL.host!),
      ("Origin", endpoint.absoluteString),
      ("Pragma", "no-cache"),
      ("User-Agent", disguise.userAgent),
    ]

    socket = WebSocket(
      endpoint: gatewayURL,
      additionalHeaders: additionalHeaders
    )

    eventHandler = socket!.events.sink(receiveCompletion: { [weak self] error in
      switch error {
      case .finished:
        self?.log.info("disconnected cleanly")
      case let .failure(error):
        self?.log.error("disconnected with error: \(error.debugDescription)")
      }
      self?.heartbeatTimer = nil
    }, receiveValue: { [weak self] event in
      guard let self = self else { return }

      Task {
        await self.handleWebSocketEvent(event)
      }
    })

    log.info("connecting to \(gatewayURL)...")
    socket!.connect()
  }

  /// Disconnect from the Discord gateway.
  public func disconnect(withCloseCode closeCode: NWProtocolWebSocket
    .CloseCode = .protocolCode(.normalClosure)) async throws
  {
    guard let socket = socket else {
      preconditionFailure("no socket")
    }

    try await socket.disconnect(withCloseCode: closeCode)
    heartbeatTimer = nil
  }

  /// Encodes a JSON payload and sends it through the gateway socket.
  public func send(json: JSON) async throws {
    guard let socket = socket else {
      preconditionFailure("cannot send JSON when not connected")
    }

    let encoder = FineJSONEncoder()
    encoder.optionalEncodingStrategy = .explicitNull
    encoder.jsonSerializeOptions = JSONSerializeOptions(isPrettyPrint: false)
    guard let data = try? encoder.encode(json) else {
      fatalError("failed to encode JSON data to send")
    }

    log.info("<- \(String(data: data, encoding: .utf8)!)")
    try await socket.send(data: data)
  }

  /// Sends a single heartbeat to the Discord gateway.
  public func heartbeat() async throws {
    try await send(json: .object(.init([
      "op": .number(String(Opcode.heartbeat.rawValue)),
      "d": .number(String(sequence ?? 0)),
    ])))
  }

  /// Begin heartbeating at a fixed interval.
  func beginHeartbeating(every interval: TimeInterval) {
    log.info("<3beating every \(interval)s")
    heartbeatTimer = Timer.publish(
      every: interval,
      tolerance: nil,
      on: .main,
      in: .default
    )
    .autoconnect()
    .sink { [weak self] _ in
      guard let self = self else { return }

      Task {
        try await self.heartbeat()
      }
    }
  }

  /// `IDENTIFY` to the Discord gateway.
  public func identify() async throws {
    // Last update: 2021-11-11
    let identifyPayload: JSON = .object(.init([
      "d": .object(.init([
        "capabilities": .number(String(disguise.capabilities)),
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
        "properties": disguise.superPropertiesJSON(),
        "token": .string(token),
      ])),
      "op": .number(String(Opcode.identify.rawValue)),
    ]))

    try await send(json: identifyPayload)
  }
}

// MARK: Packet Handling

extension GatewayConnection {
  private func handleWebSocketEvent(_ event: WebSocketEvent) async {
    switch event {
    case let .connectionStateUpdate(connectionState):
      log
        .info(
          "websocket connection state is now: \(String(describing: connectionState))"
        )
    case .isGoingToClose(closeCode: let closeCode, reason: _):
      log
        .info(
          "websocket close frame received with close code: \(String(describing: closeCode))"
        )
    case let .message(data):
      guard let text = String(data: data, encoding: .utf8) else {
        log.warning("-> received binary (length: \(data.count))")
        return
      }

      log.info("-> \(text)")

      do {
        try await handlePacket(ofJSON: text)
      } catch {
        log
          .error("failed to handle packet: \(error.localizedDescription)")
      }
    }
  }

  /// Handle a single packet encoded in JSON from the Discord gateway.
  func handlePacket(ofJSON packet: String) async throws {
    let packetEncoded = packet.data(using: .utf8)!

    let decodedPacket = try! JSONSerialization
      .jsonObject(with: packetEncoded) as! [String: Any]

    let eventName = decodedPacket["t"] as? String
    let sequence = decodedPacket["s"] as? Int
    let data = decodedPacket["d"] as? [String: Any]
    let opcode = Opcode(rawValue: decodedPacket["op"] as! Int)!

    log
      .debug(
        "t:\(String(describing: eventName)), s:\(String(describing: sequence)), op:\(opcode.rawValue)"
      )

    if let sequence = sequence {
      self.sequence = sequence
    }

    let packet = GatewayPacket<Any>(
      op: opcode,
      data: data as Any,
      sequence: sequence,
      eventName: eventName
    )
    packets.send(packet)

    switch opcode {
    case .dispatch:
      break
    case .hello:
      let heartbeatIntervalMilliseconds = data?["heartbeat_interval"] as! Int
      beginHeartbeating(every: Double(heartbeatIntervalMilliseconds) / 1000.0)
      try await identify()
    case .heartbeat:
      try await heartbeat()
    default:
      break
    }
  }
}
