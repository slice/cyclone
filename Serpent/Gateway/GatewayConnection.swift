import Combine
import Foundation
import Network
import os
import SwiftyJSON

extension NWConnection.State {
  /// A Boolean indicating whether the connection was severed.
  var didDisconnect: Bool {
    switch self {
    case .failed(_): return true
    case .cancelled: return true
    default: return false
    }
  }
}

/// A connection to the Discord gateway.
///
/// Encapsulates a `WebSocket` connection and handles any logic relating
/// specific to the Discord gateway.
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

  /// The task used to handle incoming WebSocket events.
  private var eventHandler: Task<Void, Never>?

  /// The Discord user token to `IDENTIFY` to the gateway with.
  private var token: String

  /// A Combine subject for all WebSocket state changes.
  ///
  /// This resolves to the same subject that is exposed on the underlying
  /// `WebSocket`. When reconnecting, make sure to recreate your sinks when a
  /// value gets sent to the ``reconnects`` subject.
  public var connectionState: CurrentValueSubject<WebSocketState, Never>? {
    socket?.state
  }

  /// A subject that publishes upon reconnections.
  public let reconnects = PassthroughSubject<(), Never>()

  /// A subject for all received gateway packets.
  public private(set) var receivedPackets = PassthroughSubject<AnyGatewayPacket, Never>()

  /// A subject for all sent gateway packets.
  public private(set) var sentPackets = PassthroughSubject<(json: JSON, raw: String), Never>()

  /// How long to wait between reconnects in seconds.
  private var reconnectionBackoff: Double = defaultReconnectionBackoff

  private static let defaultReconnectionBackoff: Double = 5.0

  /// Whether the connection is currently pending a reconnection.
  ///
  /// If this is `true`, then any future connection state change to ``WebSocketState/connected``
  /// or `NWConnection.State.ready` means that we have reconnected.
  private var isReconnecting: Bool = false

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

    setupEventHandler()

    log.info("connecting to \(gatewayURL)...")
    socket!.connect()
  }

  private func setupEventHandler() {
    if let eventHandler = eventHandler {
      log.debug("cancelled existing event handler")
      eventHandler.cancel()
    }

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

        self.log.info("events stream completed cleanly")
      } catch {
        self.log.error("events stream completed with failure: \(String(describing: error))")
        // The WebSocket has disconnected by now.
        self.cleanupAfterDisconnect()
      }
    }
  }

  private func cleanupAfterDisconnect() {
    heartbeatTimer = nil
  }

  /// Disconnect from the Discord gateway.
  public func disconnect(withCloseCode closeCode: NWProtocolWebSocket
    .CloseCode = .protocolCode(.normalClosure)) async throws
  {
    guard let socket = socket else {
      preconditionFailure("no socket")
    }

    try await socket.disconnect(withCloseCode: closeCode)
    cleanupAfterDisconnect()
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

// MARK: Reconnecting

extension GatewayConnection {
  private func reconnect() async throws {
    guard let socket = socket else {
      log.error("can't reconnect; socket is nil")
      return
    }

    log.notice("attempting to reconnect (backoff: \(self.reconnectionBackoff)s)")

    // TODO: Implement resuming.
    // https://discord.com/developers/docs/topics/gateway#resuming
    sequence = 0
    isReconnecting = true

    try await Task.sleep(nanoseconds: UInt64(self.reconnectionBackoff * 1_000_000_000))
    log.notice("sleep finished; reconnecting now")

    // Recreate the underlying NWConnection object, and create new event and
    // WebSocketState subjects.
    socket.reconnect()

    // Reset our sink for the event subject.
    setupEventHandler()

    // Downstream consumers should now reset their sinks.
    reconnects.send(())

    reconnectionBackoff *= 2.0
  }
}

// MARK: Packet Handling

extension GatewayConnection {
  private func handleWebSocketEvent(_ event: WebSocketEvent) async {
    switch event {
    case let .connectionStateUpdate(connectionState):
      if connectionState.didDisconnect {
        self.log.info("cancelling heartbeat timer")
        heartbeatTimer = nil
      }

      if case .failed(_) = connectionState {
        Task.detached {
          self.log.notice("triggering the reconnection process now")
          do {
            try await self.reconnect()
          } catch {
            self.log.error("failed to reconnect: \(String(describing: error))")
          }
        }
      }

      if case .ready = connectionState {
        if isReconnecting {
          self.log.info("connection became ready while reconnecting, .restart()ing connection to make it back to discord land")

          // We need to call `restart` here because the connection seems to get
          // stuck otherwise. This only applies during a reconnection.
          //
          // I've been testing reconnections by turning off Wi-Fi after
          // connecting, which causes the connection to die due to failing to
          // read a heartbeat response. Then, the connection goes into waiting
          // until we get become ready again. Finally, it gets stuck unless we
          // call this method, so this is why I'm doing this.
          socket!.connection.restart()

          isReconnecting = false
        }

        // If we make a successful connection, reset the backoff.
        reconnectionBackoff = Self.defaultReconnectionBackoff
      }

      log.info("websocket connection state is now: \(String(describing: connectionState))")
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
    let decoder = SerpentJSONDecoder()

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
