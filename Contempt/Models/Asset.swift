public enum AssetType: String {
  case icon = "icon"
  case avatar = "avatar"
}

public struct Asset {
  let type: AssetType
  let parent: Snowflake
  let hash: String

  func url(withFileExtension fileExtension: String) -> URL {
    URL(string: "https://cdn.discordapp.com/\(type.rawValue)/\(parent)/\(hash).\(fileExtension)")!
  }
}
