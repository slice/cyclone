/// A subscription to guild events.
public struct GuildSubscription: Codable {
  /// The guild in question to subscribe to events to.
  public let guild: Ref<Guild>
  public let activities: Bool
  public let threads: Bool

  /// A Boolean indicating whether typing (``TYPING_START``) events are received.
  public let typing: Bool

  public init(guild: Ref<Guild>, activities: Bool, threads: Bool, typing: Bool) {
    self.guild = guild
    self.activities = activities
    self.threads = threads
    self.typing = typing
  }

  enum CodingKeys: String, CodingKey {
    case guild = "guild_id"
    case activities, threads, typing
  }
}
