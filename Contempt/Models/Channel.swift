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

public struct Channel {
  let id: Snowflake
//  let guildID: Snowflake
  let name: String
  let type: ChannelType
  let position: Int
  let topic: String?
  let parentID: Snowflake?

  init(json: JSON) {
    id = Snowflake(string: json["id"]!.stringValue!)
//    guildID = Snowflake(string: json["guild_id"]!.stringValue!)
    name = json["name"]!.stringValue!
    type = ChannelType(rawValue: Int(json["type"]!.doubleValue!))!
    position = Int(json["position"]!.doubleValue!)
    topic = json["topic"]?.stringValue
    parentID = json["parent_id"]?.stringValue.map(Snowflake.init(string:))
  }
}
