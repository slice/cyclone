import GenericJSON

public struct Guild: Identifiable {
  public let name: String
  public let id: Snowflake
  public let icon: Asset?
  public let channels: [Channel]

  init(json: JSON) {
    let object = json.objectValue!
    name = object["name"]!.stringValue!
    id = Snowflake(string: object["id"]!.stringValue!)
    if let iconHash = object["icon"]?.stringValue {
      icon = Asset(type: .icon, parent: id, hash: iconHash)
    } else {
      icon = nil
    }
    channels = object["channels"]!.arrayValue!.map(Channel.init(json:))
  }
}
