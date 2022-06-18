import Foundation

public enum ChannelType: Int, Codable {
  case text = 0
  case dm = 1
  case voice = 2
  case groupDM = 3
  case category = 4
  case news = 5
  case store = 6
  case newsThread = 10
  case publicThread = 11
  case privateThread = 12
  case stageVoice = 13
}

public struct Channel: Identifiable {
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

extension Channel: Decodable {
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
