public struct User: Identifiable {
  public let username: String
  public let publicFlags: Int?
  public let id: Snowflake
  public let discriminator: String
  public let avatar: Asset?
  public let globalName: String?
  public var displayAvatar: Asset {
    avatar ?? Asset(defaultAvatarForUser: self)
  }

  /// Returns a boolean indicating whether the user has migrated to Discord's
  /// 2023 username system.
  ///
  /// For more information, see: https://support.discord.com/hc/en-us/articles/12620128861463
  public var pomelo: Bool {
    discriminator == "0"
  }

  public init(fakeWithName name: String, id: Snowflake) {
    username = name
    publicFlags = 0
    self.id = id
    discriminator = "0001"
    avatar = nil
    globalName = nil
  }
}

extension User: Hashable {
  public static func == (lhs: User, rhs: User) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
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
    globalName = try decoder.decodeIfPresent("global_name")
  }
}
