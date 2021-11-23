import GenericJSON

public struct Guild {
  let name: String
  let id: Snowflake
  let icon: Asset
  let channels: [Channel]

  init(json: JSON) {
    let object = json.objectValue!
    name = object["name"]!.stringValue!
    id = Snowflake(string: object["id"]!.stringValue!)
    icon = Asset(type: .icon, parent: id, hash: object["icon"]!.stringValue!)
    channels = object["channels"]!.arrayValue!.map(Channel.init(json:))
  }
}
