import GenericJSON

public struct CurrentUser: Identifiable {
  public let username: String
  public let email: String
  public let id: Snowflake
  public let discriminator: String
  public let avatar: Asset?

  init(json: JSON) {
    let object = json.objectValue!
    username = object["username"]!.stringValue!
    email = object["email"]!.stringValue!
    let id = Snowflake(string: object["id"]!.stringValue!)
    discriminator = object["discriminator"]!.stringValue!
    avatar = object["avatar"]?.stringValue.map { hash in
      Asset(type: .avatar, parent: id, hash: hash)
    }
    self.id = id
  }
}
