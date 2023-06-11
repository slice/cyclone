public struct Guild: Identifiable {
  public let channels: [GuildChannel]
  public let properties: GuildProperties

  public var id: Snowflake {
    properties.id
  }
}

public struct GuildProperties {
  public let id: Snowflake
  public let name: String
  public let icon: Asset?
}

extension GuildProperties: Decodable {
  public init(from decoder: Decoder) throws {
    id = try decoder.decode("id")
    name = try decoder.decode("name")
    if let iconHash = try decoder.decode("icon", as: String?.self) {
      icon = Asset(type: .icon, parent: id, hash: iconHash)
    } else {
      icon = nil
    }
  }
}

extension Guild: Decodable {
  public init(from decoder: Decoder) throws {
    channels = try decoder.decode("channels")
    properties = try decoder.decode("properties")
  }
}
