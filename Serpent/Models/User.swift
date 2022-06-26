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
    let id: Snowflake = try decoder.decode("id")
    self.id = id
    discriminator = try decoder.decode("discriminator")
    avatar = try decoder.decodeIfPresent("avatar").map { Asset(type: .avatar, parent: id, hash: $0) }
  }
}
