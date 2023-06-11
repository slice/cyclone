/// The Discord gateway's `READY` payload.
public struct ReadyPacket: Decodable {
  public let user: CurrentUser
  public let users: [User]
  public let guilds: [Guild]
  public let privateChannels: [PrivateChannel]

  enum CodingKeys: String, CodingKey {
    case user
    case users
    case guilds
    case privateChannels = "private_channels"
  }
}
