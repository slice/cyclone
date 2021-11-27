import Foundation
import GenericJSON

public enum ChannelType: Int {
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
//  let guildID: Snowflake
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

  init(json: JSON) {
    id = Snowflake(string: json["id"]!.stringValue!)
//    guildID = Snowflake(string: json["guild_id"]!.stringValue!)
    name = json["name"]!.stringValue!
    type = ChannelType(rawValue: Int(json["type"]!.doubleValue!))!
    position = Int(json["position"]!.doubleValue!)
    topic = json["topic"]?.stringValue
    parentID = json["parent_id"]?.stringValue.map(Snowflake.init(string:))
    overwrites = json["permission_overwrites"]!.arrayValue!
      .map { PermissionOverwrites(json: $0) }
  }
}
