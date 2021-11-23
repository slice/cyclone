import GenericJSON

public struct Guild: Identifiable {
  public let name: String
  public let id: Snowflake
  public let icon: Asset
  public let channels: [Channel]

  init(json: JSON) {
    let object = json.objectValue!
    name = object["name"]!.stringValue!
    id = Snowflake(string: object["id"]!.stringValue!)
    icon = Asset(type: .icon, parent: id, hash: object["icon"]!.stringValue!)
    channels = object["channels"]!.arrayValue!.map(Channel.init(json:))
  }
}
