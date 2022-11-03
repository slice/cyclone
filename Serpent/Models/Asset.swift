public enum AssetType: String, CaseIterable {
  case icon = "icons"
  case avatar = "avatars"
  case channelIcon = "channel-icons"
}

public struct Asset {
  public let type: AssetType
  public let parent: Snowflake
  public let hash: String

  public init(type: AssetType, parent: Snowflake, hash: String) {
    self.type = type
    self.parent = parent
    self.hash = hash
  }

  public init(avatarForUser userID: Ref<User>, hash: String) {
    self.type = .avatar
    self.parent = userID.id
    self.hash = hash
  }

  public func url(withFileExtension fileExtension: String) -> URL {
    Constants.cdnURL
      .appendingPathComponent(type.rawValue)
      .appendingPathComponent(parent.string)
      .appendingPathComponent("\(hash).\(fileExtension)")
  }
}
