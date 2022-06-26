public enum AssetType: String, CaseIterable {
  case icon = "icons"
  case avatar = "avatars"
  case channelIcon = "channel-icons"
}

public struct Asset {
  public let type: AssetType
  public let parent: Snowflake
  public let hash: String

  public func url(withFileExtension fileExtension: String) -> URL {
    Constants.cdnURL
      .appendingPathComponent(type.rawValue)
      .appendingPathComponent(parent.string)
      .appendingPathComponent("\(hash).\(fileExtension)")
  }
}
