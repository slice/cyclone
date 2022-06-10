public struct User: Identifiable {
  public let username: String
  public let publicFlags: Int?
  public let id: Snowflake
  public let discriminator: String
  public let avatar: Asset?

  public init(fakeWithName name: String, id: Snowflake) {
    username = name
    publicFlags = 0
    self.id = id
    discriminator = "0001"
    avatar = nil
  }
}

extension User: Decodable {
  public init(from decoder: Decoder) throws {
    username = try decoder.decode("username")
    publicFlags = try decoder.decodeIfPresent("public_flags")
    id = try decoder.decode("id")
    discriminator = try decoder.decode("discriminator")
    avatar = Asset(type: .avatar, parent: id, hash: try decoder.decode("avatar", as: String.self))
  }
}
