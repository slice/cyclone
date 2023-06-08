public enum AssetType: String, CaseIterable {
  case icon = "icons"
  case avatar = "avatars"
  case channelIcon = "channel-icons"
  case embed = "embed"
}

public struct Asset {
  public let type: AssetType
  let parent: String
  let hash: String

  public init(type: AssetType, parent: Snowflake, hash: String) {
    self.type = type
    self.parent = parent.string
    self.hash = hash
  }

  public init(avatarForUser userID: Ref<User>, hash: String) {
    self.type = .avatar
    self.parent = userID.id.string
    self.hash = hash
  }

  public init (defaultAvatarForUser user: User) {
    self.type = .embed
    self.parent = "avatars"

    let numberOfDefaultAvatars: UInt64 = 4
    let base = user.pomelo ? user.id.uint64 >> 22 : (UInt64(user.discriminator) ?? 0)
    let index = base % numberOfDefaultAvatars
    self.hash = String(index)
  }

  public func url(withFileExtension fileExtension: String) -> URL {
    Constants.cdnURL
      .appendingPathComponent(type.rawValue)
      .appendingPathComponent(parent)
      .appendingPathComponent("\(hash).\(fileExtension)")
  }
}
