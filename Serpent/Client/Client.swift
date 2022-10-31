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

  /// The associated cache used for tracking state.
  public private(set) var cache = Cache()

  /// The task that handles incoming gateway packets.
  private var packetHandlerTask: Task<Void, Never>?

  /// A Combine `Publisher` that publishes when the gateway sends us `READY`.
  ///
  /// By the time this publishes, the ``cache`` will be populated with values.
  public private(set) var ready = PassthroughSubject<Void, Never>()

  /// A Combine `Publisher` that publishes when the client's guild list has
  /// changed in some way.
  public private(set) var guildsChanged = PassthroughSubject<Void, Never>()

  /// A Combine `Publisher` that publishes when the client's private channel
  /// list has changed in some way.
  public private(set) var privateChannelsChanged = PassthroughSubject<Void, Never>()

  /// A Combine `Publisher` that publishes new typing events.
  public private(set) var typingEvents = PassthroughSubject<TypingEvent, Never>()

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

  public init(baseURL: URL, token: String) {
    guard !token.isEmpty else {
      preconditionFailure("attempted to make client with empty token")
    }
    self.token = token

    self.endpoint = baseURL

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
  public func connect(gatewayURL: URL) {
    packetHandlerTask = Task.detached(priority: .high) {
      for await packet in self.gatewayConnection.receivedPackets.bufferInfinitely().values {
        do {
          try await self.processPacket(packet)
        } catch let error as DecodingError {
          self.log.error("failed to decode gateway packet: \(error, privacy: .public) while processing packet: \(String(describing: packet), privacy: .public)")
          fatalError("failed to decode a gateway packet, whoops!")
        } catch {
          self.log.error("failed to process gateway packet: \(error, privacy: .public)")
          fatalError("failed to process a gateway packet, whoops!")
        }
      }
    }

    gatewayConnection.connect(
      toGateway: gatewayURL,
      fromDiscordEndpoint: endpoint
    )
  }

  func processPacket(_ packet: AnyGatewayPacket) async throws {
    guard let eventName = packet.packet.eventName,
          let eventData = packet.packet.eventData else {
      return
    }

    switch eventName {
    case "READY":
      log.debug("discord is READY. now we have to get READY!")
      try await cache.ingestReadyPacket(packet)
      guildsChanged.send()
      privateChannelsChanged.send()
      ready.send()
    case "MESSAGE_CREATE":
      let message: Message = try packet.reparse()
      let channelID = Snowflake(string: packet.packet.eventData!["channel_id"].string!)
      await cache.endTyping(user: message.author.id, location: channelID)
    case "GUILD_CREATE":
      let guild: Guild = try packet.reparse()
      await cache.upsert(guild: guild)
    case "USER_SETTINGS_UPDATE":
      await cache.upsert(userSettings: eventData)
    case "TYPING_START":
      // If the typing event contains a user (which is the case in guilds),
      // upsert them into the cache in case we don't know about this yet.
      if let user: User = try packet.packet.eventData?["member"]["user"].reparse() {
        await cache.upsert(user: user)
      }

      let event: TypingEvent = try packet.reparse()
      typingEvents.send(event)
      await cache.beginTyping(user: event.user.id, at: event.timestamp, location: event.channel.id)
    default:
      break
    }
  }

  /// Disconnect from the Discord gateway.
  public func disconnect() async throws {
    packetHandlerTask?.cancel()
    try await gatewayConnection.disconnect()
  }
}
