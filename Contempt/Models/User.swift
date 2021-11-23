import GenericJSON

public struct User: Identifiable {
  public let username: String
  public let publicFlags: Int
  public let id: Snowflake
  public let discriminator: String
  public let avatar: Asset?

  init(json: JSON) {
    let object = json.objectValue!
    username = object["username"]!.stringValue!
    publicFlags = Int(object["public_flags"]!.doubleValue!)
    let id = Snowflake(string: object["id"]!.stringValue!)
    discriminator = object["discriminator"]!.stringValue!
    avatar = object["avatar"]?.stringValue.map { hash in
      Asset(type: .avatar, parent: id, hash: hash)
    }
    self.id = id
  }

  public init(fakeWithName name: String, id: Snowflake) {
    username = name
    publicFlags = 0
    self.id = id
    discriminator = "0001"
    avatar = nil
  }
}
