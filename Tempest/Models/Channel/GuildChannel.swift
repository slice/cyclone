import Foundation

/// A text, voice, category, etc. channel in a guild.
public struct GuildChannel: Identifiable {
  public let id: Snowflake
  public let name: String
  public let type: ChannelType
  public let position: Int
  public let topic: String?
  public let parentID: Snowflake?
  public let overwrites: [PermissionOverwrites]

  /// Returns whether the channel is not within a category, or is a category
  /// itself.
  public var isTopLevel: Bool {
    type == .category || parentID == nil
  }
}

extension GuildChannel: Decodable {
  public init(from decoder: Decoder) throws {
    id = try decoder.decode("id")
    type = try decoder.decode("type")
    name = try decoder.decode("name")
    position = try decoder.decode("position")
    topic = try decoder.decodeIfPresent("topic")
    parentID = try decoder.decodeIfPresent("parent_id")
    overwrites = try decoder.decode("permission_overwrites")
  }
}
