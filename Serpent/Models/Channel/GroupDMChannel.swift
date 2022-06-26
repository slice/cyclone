/// A group direct message channel.
public struct GroupDMChannel: Identifiable {
  public let id: Snowflake
  public let icon: Asset?
  public let lastMessageID: Ref<Message>?
  public let lastPinTimestamp: Date?
  public let name: String?
  public let ownerID: Ref<User>
  public let recipients: [Ref<User>]
}

extension GroupDMChannel: Decodable {
  public init(from decoder: Decoder) throws {
    let id: Snowflake = try decoder.decode("id")
    icon = try decoder.decodeIfPresent("icon").map { Asset(type: .channelIcon, parent: id, hash: $0) }
    self.id = id
    lastMessageID = try decoder.decodeIfPresent("last_message_id")
    lastPinTimestamp = try decoder.decodeIfPresent("last_pin_timestamp")
    name = try decoder.decodeIfPresent("name")
    ownerID = try decoder.decode("owner_id")
    recipients = try decoder.decode("recipient_ids")
  }
}
