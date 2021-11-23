public enum AssetType: String {
  case icon
  case avatar
}

public struct Asset {
  public let type: AssetType
  public let parent: Snowflake
  public let hash: String

  public func url(withFileExtension fileExtension: String) -> URL {
    URL(
      string: "https://cdn.discordapp.com/\(type.rawValue)s/\(parent.uint64)/\(hash).\(fileExtension)"
    )!
  }
}
