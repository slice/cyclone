import Combine
import Foundation
import Network
import os
import SwiftyJSON

extension NWConnection.State {
  /// A Boolean indicating whether the connection was severed.
  var didDisconnect: Bool {
    switch self {
    case .failed: true
    case .cancelled: true
    default: false
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
    DispatchQueue(label: "tempest-gateway-connection")

  /// The timer used to manage periodic heartbeating.
  private var heartbeatTimer: AnyCancellable?

  /// The task used to handle incoming WebSocket events.
  private var eventHandler: Task<Void, Never>?

  /// The Discord user token to `IDENTIFY` to the gateway with.
  private var token: String

  /// The point in time marking this connection's creation.
  private var created: Date

  private var decompression: Decompression?
  private var decompressionBuffer: Data?

  /// A Combine subject for all WebSocket state changes.
  ///
  /// This resolves to the same subject that is exposed on the underlying
  /// `WebSocket`. When reconnecting, make sure to recreate your sinks when a
  /// value gets sent to the ``reconnects`` subject.
  public var connectionState: CurrentValueSubject<WebSocketState, Never>? {
    socket?.state
  }

  /// A subject that publishes upon reconnections.
  public let reconnects = PassthroughSubject<Void, Never>()

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

  /// The guild subscriptions managed by this gateway connection.
  ///
  /// It is unknown whether this is what the official client actually does to
  /// track guild subscriptions, so we are making a guess here.
  public var guildSubscriptions: [Guild.ID: GuildSubscription] = [:]

  /// The "call connections" managed by this gateway connection.
  ///
  /// This is not related to Discord voice calls or voice channels. Discord
  /// sends an OP 13 ``CALL_CONNECT`` to (group) direct message channels in
  /// order to subscribe to typing events.
  public var callConnections: [Snowflake] = []

  deinit {
    heartbeatTimer = nil
  }

  /// Initializes a new Discord gateway connection with a certain user token and
  /// disguise.
  init(token: String, disguise: Disguise) {
    self.token = token
    self.disguise = disguise
    self.created = Date.now
    self.log = Logger(subsystem: "zone.slice.Tempest", category: "gateway")
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

    if gatewayURL.relativeString.contains("zlib-stream") {
      log.info("setting up decompression context")
      decompressionBuffer = Data()
      decompression = Decompression()
    }

    socket = WebSocket(
      endpoint: gatewayURL,
      additionalHeaders: additionalHeaders
    )

    setupEventHandler()

    log.info("connecting to \(gatewayURL)...")
    socket!.connect()
  }

  private func setupEventHandler() {
    if let eventHandler {
      log.debug("cancelled existing event handler")
      eventHandler.cancel()
    }

    eventHandler = Task.detached(priority: .high) { [weak self] in
      guard let self, let socket = self.socket else { return }

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
    guard let socket else {
      preconditionFailure("no socket")
    }

    try await socket.disconnect(withCloseCode: closeCode)
    cleanupAfterDisconnect()
  }

  /// Encodes a JSON payload and sends it through the gateway socket.
  public func send(json: JSON) async throws {
    guard let socket else {
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

  /// Sends a new guild subscription to the gateway.
  public func updateGuildSubscription(for guildID: Guild.ID, subscription: GuildSubscription) async throws {
    let json: JSON = [
      "op": Opcode.guildSubscriptions.rawValue,
      "d": try JSON(subscription.encoded()),
    ]
    try await send(json: json)
    guildSubscriptions[guildID] = subscription
  }

  /// Sends a "call connect" event to the gateway.
  public func sendCallConnect(for channelID: Snowflake) async throws {
    let json: JSON = ["op": Opcode.callConnect.rawValue, "d": ["channel_id": channelID.string]]
    try await send(json: json)
    callConnections.append(channelID)
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
      guard let self else { return }

      Task {
        try await self.heartbeat()
      }
    }
  }

  /// `IDENTIFY` to the Discord gateway.
  public func identify() async throws {
    // Last update: 2021-11-11
    let superProperties = try JSON(disguise.superProperties.encoded())

    let identifyPayload: JSON = [
      "d": [
        "capabilities": JSON(disguise.capabilities.rawValue),
        "client_state": [
          "guild_hashes": [:] as JSON,
          "highest_last_message_id": "0",
          "read_state_version": 0,
          "user_guild_settings_version": -1,
          "user_settings_version": -1,
        ] as JSON,
        // TODO(skip): Implement compression.
        "compress": true,
        "presence": [
          "activities": [] as JSON,
          "afk": false,
          "since": 0,
          "status": "online",
        ] as JSON,
        "properties": superProperties,
        "token": token,
      ] as JSON,
      "op": Opcode.identify.rawValue,
    ]

    try await send(json: identifyPayload)
  }
}

// MARK: Reconnecting

extension GatewayConnection {
  private func reconnect() async throws {
    guard let socket else {
      log.error("can't reconnect; socket is nil")
      return
    }

    log.notice("attempting to reconnect (backoff: \(self.reconnectionBackoff)s)")

    // TODO: Implement resuming.
    // https://discord.com/developers/docs/topics/gateway#resuming
    sequence = 0
    guildSubscriptions = [:]
    callConnections = []
    isReconnecting = true
    try decompression?.reset()

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
  private func dumpEventData(data: Data, isBinary: Bool = true) throws {
    let format = Date.ISO8601FormatStyle(
      dateSeparator: .dash,
      dateTimeSeparator: .space,
      timeSeparator: .omitted
    )
    let sequence = self.sequence.map { String($0) } ?? Date.now.formatted(format)
    let fileExtension = isBinary ? "dat" : "txt"
    let name = "TempestGatewayEvent-\(self.created.formatted(format))-\(sequence).\(fileExtension)"
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    NSLog("*** Dumping data to %@", path.absoluteString)
    try data.write(to: path)
  }

  private func handleWebSocketEvent(_ event: WebSocketEvent) async {
    switch event {
    case let .connectionStateUpdate(connectionState):
      if connectionState.didDisconnect {
        self.log.info("cancelling heartbeat timer")
        heartbeatTimer = nil
      }

      if case .failed = connectionState {
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
      }

      log.info("websocket connection state is now: \(String(describing: connectionState))")
    case .isGoingToClose(closeCode: let closeCode, reason: _):
      log
        .info(
          "websocket close frame received with close code: \(String(describing: closeCode))"
        )
    case let .message(wireData):
      // TODO: Only accept either compressed or raw packets all the time, so we
      // don't have to waste time checking.
      var preliminaryText = String(data: wireData, encoding: .utf8)
      let isBinary = preliminaryText == nil

      if UserDefaults.standard.bool(forKey: SerpentDefaults.dumpAllPackets.rawValue) {
        try! self.dumpEventData(data: wireData, isBinary: isBinary)
      }

      var decompressedData: Data?
      if isBinary {
        guard let decompression else {
          fatalError("received binary message, but no decompressor was set up")
        }

        log.debug("received binary packet with len \(wireData.count)")
        decompressionBuffer!.append(wireData)

        if wireData.suffix(4) == [0, 0, 0xff, 0xff] {
          log.debug("noticed Z_SYNC_FLUSH, decompressing")
          do {
            decompressedData = try decompression.decompress(decompressionBuffer!)
            guard let decompressedText = String(data: decompressedData!, encoding: .utf8) else {
              fatalError("decompressed data wasn't valid UTF-8")
            }

            log.debug("decompressed OK (over wire: \(wireData.count), actual: \(decompressedData!.count))")
            preliminaryText = decompressedText
          } catch {
            fatalError("failed to decompress: \(error)")
          }
          decompressionBuffer = Data()
        }
      }

      let text = preliminaryText!
      let data = isBinary ? decompressedData! : wireData

      if UserDefaults.standard.bool(forKey: SerpentDefaults.logReceivedWebSocketMessages.rawValue) {
        log.info("-> \(text)")
      }

      do {
        try await handlePacket(ofJSON: text, raw: data)
      } catch {
        log
          .error("failed to handle packet: \(error.localizedDescription), \(error)")
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
    ofJSON _: String,
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

    if let sequence {
      self.sequence = sequence
    }

    receivedPackets.send(AnyGatewayPacket(packet: packet, raw: packetBytes))

    switch op {
    case .dispatch:
      if packet.eventName == "READY" {
        // If we make a successful connection, reset the backoff.
        reconnectionBackoff = Self.defaultReconnectionBackoff
      }
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
