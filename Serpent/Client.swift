import Combine
import Dispatch
import Foundation
import Network
import os
import SwiftyJSON

// MARK: Client

/// A Discord user client.
public class Client {
  /// The user authentication token used to connect to Discord.
  var token: String

  /// The Discord API endpoint that we communicate with.
  var endpoint: URL

  /// The disguise to use when communicating with Discord.
  var disguise: Disguise

  private var log: Logger

  /// The connection to the Discord gateway.
  public var gatewayConnection: GatewayConnection!

  /// The Discord API HTTP client.
  public var http: HTTP!

  var gatewaySink: AnyCancellable!

  /// The user's settings, received from the `READY` packet.
  public private(set) var userSettings: JSON?
  public private(set) var currentUser: CurrentUser?

  /// A Combine `Publisher` that publishes when the user settings have changed.
  /// The partial data fragment sent by the gateway is published.
  public private(set) var userSettingsChanged = PassthroughSubject<JSON, Never>()

  /// The guilds that this client has.
  public private(set) var guilds: [Guild] = []

  /// The private (DM, group DM) channels visible to the client.
  public private(set) var privateChannels: [PrivateChannel] = []

  /// A Combine `Publisher` that publishes when the client's guild list has
  /// changed in some way.
  public private(set) var guildsChanged = PassthroughSubject<Void, Never>()

  /// A Combine `Publisher` that publishes when the client's private channel
  /// list has changed in some way.
  public private(set) var privateChannelsChanged = PassthroughSubject<Void, Never>()

  static let defaultDisguise = Disguise(
    userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) discord/0.0.278 Chrome/91.0.4472.164 Electron/13.4.0 Safari/537.36",
    capabilities: 509,
    os: "Mac OS X",
    browser: "Discord Client",
    releaseChannel: .canary,
    clientVersion: "0.0.62",
    osVersion: "21.5.0",
    osArch: "arm64",
    systemLocale: "en-US",
    clientBuildNumber: 132857,
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
    disguise = Self.defaultDisguise

    log = Logger(subsystem: "zone.slice.Serpent", category: "client")
    gatewayConnection = GatewayConnection(
      token: self.token,
      disguise: disguise
    )

    http = HTTP(baseURL: endpoint, token: token, disguise: disguise)
  }

  /// Connect to the Discord gateway.
  public func connect() {
    gatewaySink = gatewayConnection.receivedPackets.sink { [weak self] packet in
      do {
        try self?.processPacket(packet)
      } catch let error as DecodingError {
        self?.log.error("failed to decode packet: \(String(describing: error), privacy: .public)")
        self?.log.error("while processing packet: \(String(describing: packet))")
        fatalError("failed to decode a gateway packet, whoops.")
      } catch {
        self?.log.error("failed to process packet: \(String(describing: error), privacy: .public)")
        fatalError("failed to process a gateway packet, whoops.")
      }
    }

    gatewayConnection.connect(
      toGateway: URL(string: "wss://gateway.discord.gg/?encoding=json&v=9")!,
      fromDiscordEndpoint: endpoint
    )
  }

  func handleReady(packet: AnyGatewayPacket) throws {
    guard let eventData = packet.packet.eventData else {
      return
    }

    struct Ready: Decodable {
      let user: CurrentUser
      let guilds: [Guild]
      let privateChannels: [PrivateChannel]

      enum CodingKeys: String, CodingKey {
        case user = "user"
        case guilds = "guilds"
        case privateChannels = "private_channels"
      }
    }

    let ready: Ready = try packet.reparse()
    currentUser = ready.user

    guilds = ready.guilds
    guildsChanged.send()

    privateChannels = ready.privateChannels
    privateChannelsChanged.send()

    userSettings = eventData["user_settings"]
    userSettingsChanged.send(userSettings!)
  }

  func processPacket(_ packet: AnyGatewayPacket) throws {
    guard let eventName = packet.packet.eventName,
          let eventData = packet.packet.eventData else {
      return
    }

    switch eventName {
    case "READY":
      log.debug("discord is READY. now we have to get READY!")
      try handleReady(packet: packet)
    case "GUILD_CREATE":
      guilds.append(try packet.reparse())
      guildsChanged.send()
    case "USER_SETTINGS_UPDATE":
      try userSettings?.merge(with: eventData)
      userSettingsChanged.send(eventData)
    default:
      break
    }
  }

  /// Disconnect from the Discord gateway.
  public func disconnect() async throws {
    try await gatewayConnection.disconnect()
  }
}
