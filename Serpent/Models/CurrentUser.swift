public struct CurrentUser: Identifiable {
  public let username: String
  public let email: String
  public let id: Snowflake
  public let discriminator: String
  public let avatar: Asset?
}

extension CurrentUser: Decodable {
  public init(from decoder: Decoder) throws {
    username = try decoder.decode("username")
    email = try decoder.decode("email")
    id = try decoder.decode("id")
    discriminator = try decoder.decode("discriminator")
    if let avatarHash = try decoder.decodeIfPresent("avatar", as: String.self) {
      avatar = Asset(type: .avatar, parent: id, hash: avatarHash)
    } else {
      avatar = nil
    }
  }
}
