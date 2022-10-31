import SwiftyJSON
import Combine
import OrderedCollections

public enum CacheError: Error {
  case readyPacketLacksEventData
}

extension Array where Element == PrivateChannel {
  func sortedChronologically() -> [PrivateChannel] {
    sorted { first, second in
      first.lastMessageID?.id ?? first.id > second.lastMessageID?.id ?? second.id
    }
  }
}

/// A cache for tracking known models.
public actor Cache {
  /// The currently authenticated user.
  public var currentUser: CurrentUser?

  /// The current user's settings.
  public var userSettings = CurrentValueSubject<JSON?, Never>(nil)

  /// All known users.
  public private(set) var users: [User.ID: User] = [:]

  /// All known private channels (DM channel, group DM channel).
  public private(set) var privateChannels: OrderedDictionary<PrivateChannel.ID, PrivateChannel> = [:]

  /// All known guilds.
  public private(set) var guilds: [Guild.ID: Guild] = [:]

  /// How long before a typing event expires.
  public static let typingEventTimeout: TimeInterval = 10.0

  /// Typing states.
  private var typing: [Snowflake: [User.ID: TypingState]] = [:]

  public func beginTyping(user: User.ID, at beganTypingAt: Date = .now, location: Snowflake) {
    var states = typing[location] ?? [:]
    states[user] = TypingState(beganTypingAt: beganTypingAt)
    typing[location] = states
  }

  public func endTyping(user: User.ID, location: Snowflake) {
    typing[location]?.removeValue(forKey: user)
  }

  /// Returns the users currently typing in a channel.
  public func usersCurrentlyTyping(in location: Snowflake) -> [User.ID: TypingState] {
    (typing[location] ?? [:]).filter { Date.now.timeIntervalSince($0.value.beganTypingAt) < Self.typingEventTimeout }
  }

  /// Populate the cache with a `READY` packet from the gateway.
  public func ingestReadyPacket(_ packet: AnyGatewayPacket) throws {
    func identifiablesToDictionary<I: Identifiable>(_ identifiables: [I]) -> [I.ID: I] {
      Dictionary(uniqueKeysWithValues: identifiables.map { ($0.id, $0) })
    }

    guard let eventData = packet.packet.eventData else {
      throw CacheError.readyPacketLacksEventData
    }

    let ready: ReadyPacket = try packet.reparse()

    currentUser = ready.user
    guilds = identifiablesToDictionary(ready.guilds)
    users = identifiablesToDictionary(ready.users)
    privateChannels = OrderedDictionary(uniqueKeysWithValues: ready.privateChannels.sortedChronologically().map { ($0.id, $0) })

    userSettings.send(eventData["user_settings"])
  }

  /// Resolves a ``Guild`` from a ``Ref``.
  public subscript(_ guild: Ref<Guild>) -> Guild? {
    get { guilds[guild.id] }
    set { guilds[guild.id] = newValue }
  }

  /// Resolves a ``User`` from a ``Ref``.
  public subscript(_ user: Ref<User>) -> User? {
    get { users[user.id] }
    set { users[user.id] = newValue }
  }

  /// Resolves a ``PrivateChannel`` from a ``Ref``.
  public subscript(_ privateChannel: Ref<PrivateChannel>) -> PrivateChannel? {
    get { privateChannels[privateChannel.id] }
    set { privateChannels[privateChannel.id] = newValue }
  }

  /// Batch resolves a set of ``User`` ``Ref``s.
  public func batchResolve(users: Set<Ref<User>>) -> Set<User> {
    Set(users.compactMap { self.users[$0.id] })
  }

  /// Adds a guild to the cache, replacing any existing guild with the same ID.
  public func upsert(guild: Guild) {
    self[guild.ref] = guild
  }

  /// Updates the user settings.
  public func upsert(userSettings: JSON) {
    self.userSettings.send(userSettings)
  }

  /// Adds a user to the cache, replacing any user with the same ID.
  public func upsert(user: User) {
    self[user.ref] = user
  }
}
