public enum AssetType: String {
  case icon
  case avatar
}

public struct Asset {
  public let type: AssetType
  public let parent: Snowflake
  public let hash: String

  public func url(withFileExtension fileExtension: String) -> URL {
    Constants.cdnURL
      .appendingPathComponent("\(type.rawValue)s")
      .appendingPathComponent(parent.string)
      .appendingPathComponent("\(hash).\(fileExtension)")
  }
}
