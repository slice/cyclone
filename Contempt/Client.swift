import Dispatch
import FineJSON
import Foundation
import Network
import NWWebSocket
import os
import RichJSONParser

// MARK: Client

/// A Discord user client.
public class Client {
  /// The user authentication token used to connect to Discord.
  var token: String

  /// The Discord API endpoint that we communicate with.
  var endpoint: URL

  /// The disguise to use when communicating with Discord.
  var disguise: Disguise

  /// The WebSocket connection to the Discord Gateway.
  var gatewaySocket: NWWebSocket?

  private var log: Logger

  /// The dispatch queue to handle Discord Gateway messages.
  var dispatchQueue = DispatchQueue(label: "contempt-gateway")
  var heartbeatTimer: DispatchSourceTimer!

  var ingestion: Ingestion!
  var sequence: Int?

  static let defaultDisguise = Disguise(
    userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) discord/0.0.278 Chrome/91.0.4472.164 Electron/13.4.0 Safari/537.36",
    capabilities: 125,
    os: "Mac OS X",
    browser: "Discord Client",
    releaseChannel: .canary,
    clientVersion: "0.0.278",
    osVersion: "21.2.0",
    osArch: "x64",
    systemLocale: "en-US",
    clientBuildNumber: 104_572,
    clientEventSource: nil
  )

  public init(branch: Branch, token: String) {
    guard !token.isEmpty else {
      preconditionFailure("attempted to make client with empty token")
    }
    self.token = token

    guard let endpoint = branch.baseURL else {
      preconditionFailure(
        "attempted to make client with branch \(branch), which has no base url"
      )
    }
    self.endpoint = endpoint

    // TODO(skip): Don't hardcode these. Scrape the necessary values at runtime.
    self.disguise = Self.defaultDisguise

    self.log = Logger(subsystem: "zone.slice.Contempt", category: "client")
    self.ingestion = Ingestion(client: self)
  }

  /// Connect to Discord.
  public func connect() {
    let gatewayURL = URL(string: "wss://gateway.discord.gg/?encoding=json&v=9")!

    let options = NWWebSocket.defaultOptions
    // Last update: 2021-11-11
    options.setAdditionalHeaders([
      ("Accept-Encoding", "gzip, deflate, br"),
      ("Accept-Language", self.disguise.systemLocale),
      ("Cache-Control", "no-cache"),
      ("Connection", "Upgrade"),
      ("Host", gatewayURL.host!),
      ("Origin", self.endpoint.absoluteString),
      ("Pragma", "no-cache"),
      ("User-Agent", self.disguise.userAgent),
    ])

    let socket = NWWebSocket(
      url: gatewayURL,
      connectAutomatically: false,
      options: options,
      connectionQueue: self.dispatchQueue
    )
    socket.delegate = self

    self.log.info("[ws] starting connection to \(gatewayURL)...")
    socket.connect()
    self.gatewaySocket = socket
  }

  /// Disconnect from Discord.
  ///
  /// If the client isn't connected, nothing happens.
  public func disconnect() {
    self.gatewaySocket?.disconnect()
  }
}

// MARK: WebSocketConnectionDelegate

extension Client: WebSocketConnectionDelegate {
  public func webSocketDidDisconnect(
    connection _: WebSocketConnection,
    closeCode _: NWProtocolWebSocket.CloseCode,
    reason _: Data?
  ) {}

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
    error _: NWError
  ) {}

  public func webSocketDidReceivePong(connection _: WebSocketConnection) {}

  public func webSocketDidReceiveMessage(
    connection _: WebSocketConnection,
    string text: String
  ) {
    self.log.info("[ws] -> \(text)")
    self.ingestion.handleGatewayMessage(text: text)
  }

  public func webSocketDidReceiveMessage(
    connection _: WebSocketConnection,
    data _: Data
  ) {
    self.log.info("[ws] -> <binary>")
  }

  public func webSocketDidConnect(connection _: WebSocketConnection) {
    self.log.info("[ws] connected")
  }
}

// MARK: Gateway Actions

extension Client {
  func send(json: JSON) {
    guard let socket = self.gatewaySocket else {
      preconditionFailure("cannot send JSON when not connected")
    }
    let encoder = FineJSONEncoder()
    encoder.optionalEncodingStrategy = .explicitNull
    encoder.jsonSerializeOptions = JSONSerializeOptions(isPrettyPrint: false)
    guard let data = try? encoder.encode(json) else {
      fatalError("failed to encode json data to send")
    }
    self.log.info("[ws] <- \(String(data: data, encoding: .utf8)!)")
    socket.send(data: data)
  }

  func beginHeartbeating(interval: DispatchTimeInterval) {
    self.heartbeatTimer = DispatchSource
      .makeTimerSource(queue: self.dispatchQueue)
    self.heartbeatTimer.setEventHandler { [weak self] in
      guard let self = self else { return }
      self.send(json: .object(.init([
        "op": .number(String(Opcode.heartbeat.rawValue)),
        "d": .number(String(self.sequence ?? 0)),
      ])))
    }
    self.heartbeatTimer.schedule(
      deadline: .now(),
      repeating: interval,
      leeway: .nanoseconds(0)
    )
    self.heartbeatTimer.resume()
  }

  func identify() {
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
