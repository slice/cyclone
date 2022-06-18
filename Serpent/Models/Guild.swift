public struct Guild: Identifiable {
  public let name: String
  public let id: Snowflake
  public let icon: Asset?
  public let channels: [Channel]
}

extension Guild: Decodable {
  public init(from decoder: Decoder) throws {
    name = try decoder.decode("name")
    id = try decoder.decode("id")
    if let iconHash = try decoder.decode("icon", as: String?.self) {
      icon = Asset(type: .icon, parent: id, hash: iconHash)
    } else {
      icon = nil
    }
    channels = try decoder.decode("channels")
  }
}
