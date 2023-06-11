import Foundation

/// A singular instance of a user beginning to type.
///
/// This is received from the gateway in the form of ``TYPING_START`` dispatch
/// packets.
public struct TypingEvent {
  public let channel: Ref<GuildChannel>
  public let guild: Ref<Guild>?
  public let user: Ref<User>
  public let timestamp: Date
}

extension TypingEvent: Decodable {
  public init(from decoder: Decoder) throws {
    channel = try decoder.decode("channel_id")
    guild = try decoder.decodeIfPresent("guild_id")
    user = try decoder.decode("user_id")
    timestamp = try Date(timeIntervalSince1970: decoder.decode("timestamp", as: Double.self))
  }
}
