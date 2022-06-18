import Combine
import Foundation
import Network
import os
import SwiftyJSON

/// A connection to the Discord gateway.
public class GatewayConnection {
  /// The WebSocket connection to the gateway.
  private var socket: WebSocket?

  /// The disguise used in this gateway connection.
  private let disguise: Disguise

  /// The latest sequence number received from the gateway.
  private(set) var sequence: Double?

  private var log: Logger

  /// The dispatch queue for handling Discord gateway messages.
  private var dispatchQueue =
    DispatchQueue(label: "serpent-gateway-connection")

  /// The timer used to manage periodic heartbeating.
  private var heartbeatTimer: AnyCancellable?

  /// The Combine subscriber used to handle incoming WebSocket events.
  private var eventHandler: Task<Void, Never>?

  /// The Discord user token to `IDENTIFY` to the gateway with.
  private var token: String

  /// A Combine subject for received gateway packets.
  public private(set) var receivedPackets = PassthroughSubject<AnyGatewayPacket, Never>()

  /// A Combine subject for sent gateway packets.
  public private(set) var sentPackets = PassthroughSubject<(JSON, String), Never>()

  deinit {
    heartbeatTimer = nil
  }

  /// Initializes a new Discord gateway connection with a certain user token and
  /// disguise.
  init(token: String, disguise: Disguise) {
    self.token = token
    self.disguise = disguise
    log = Logger(subsystem: "zone.slice.Serpent", category: "gateway")
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

    eventHandler = Task.detached(priority: .high) { [weak self] in
      guard let self = self, let socket = self.socket else { return }

      do {
        // It's important to call .bufferInfinitely here. If we don't, then any
        // gateway packet we receive while handling one already is dropped.
        // There's little documentation on this at the moment, but it appears
        // that calling Publisher.values does not buffer the values at all.
        for try await event in socket.events.bufferInfinitely().values {
          await self.handleWebSocketEvent(event)
        }

        self.log.info("disconnected cleanly")
      } catch {
        self.log.error("disconnected with error: \(error.localizedDescription)")
      }
    }

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

    guard let data = try? json.encoded() else {
      fatalError("failed to encode JSON data to send")
    }

    guard let string = String(data: data, encoding: .utf8) else {
      fatalError("failed to encode outgoing JSON data as UTF-8")
    }

    log.info("<- \(string)")
    try await socket.send(data: data)

    sentPackets.send((json, string))
  }

  /// Sends a single heartbeat to the Discord gateway.
  public func heartbeat() async throws {
    try await send(json: [
      "op": Opcode.heartbeat.rawValue,
      "d": sequence ?? 0,
    ])
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
    let superProperties = JSON(try disguise.superProperties.encoded())

    let identifyPayload: JSON = [
      "d": [
        "capabilities": disguise.capabilities,
        "client_state": [
          "guild_hashes": [:],
          "highest_last_message_id": "0",
          "read_state_version": 0,
          "user_guild_settings_version": -1,
          "user_settings_version": -1
        ],
        // TODO(skip): Implement compression.
        "compress": false,
        "presence": [
          "activities": [],
          "afk": false,
          "since": 0,
          "status": "online"
        ],
        "properties": superProperties,
        "token": token,
      ],
      "op": Opcode.identify.rawValue
    ]

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

//      log.info("-> \(text)")

      do {
        try await handlePacket(ofJSON: text, raw: data)
      } catch {
        log
          .error("failed to handle packet: \(error.localizedDescription)")
      }
    }
  }

  /// Handle a single packet encoded in JSON from the Discord gateway.
  ///
  /// This functions accepts the packet both as a string and as a byte buffer
  /// because the latter is used while deserializing the packet, and the former
  /// is used for tracing. There shouldn't be a discrepancy in contents between
  /// the two.
  func handlePacket(
    ofJSON packetJSON: String,
    raw packetBytes: Data
  ) async throws {
    let decoder = JSONDecoder()

    let packet = try decoder.decode(GatewayPacket<JSON>.self, from: packetBytes)
    let op = packet.op
    let data = packet.eventData
    let eventName = packet.eventName
    let sequence = packet.sequence

    log
      .debug(
        "op: \(String(describing: op)) (\(op.rawValue)), event: \(String(describing: eventName)), seq: \(String(describing: sequence))"
      )

    if let sequence = sequence {
      self.sequence = sequence
    }

    receivedPackets.send(AnyGatewayPacket(packet: packet, raw: packetBytes))

    switch op {
    case .dispatch:
      break
    case .hello:
      guard let heartbeatIntervalMilliseconds = data?["heartbeat_interval"].double else {
        fatalError("gateway didn't send a `heartbeat_interval` in HELLO")
      }
      beginHeartbeating(every: Double(heartbeatIntervalMilliseconds) / 1000.0)
      try await identify()
    case .heartbeat:
      try await heartbeat()
    default:
      break
    }
  }
}
