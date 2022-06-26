/// A direct message channel.
public struct DMChannel: Identifiable {
  public let id: Snowflake
  public let lastMessageID: Ref<Message>?
  // For some reason, DM channels have an array of recipients even though there
  // should only be one. Group DM channels are a separate type entirely,
  public let recipientIDs: [Ref<User>]

  public var recipient: Ref<User>? {
    recipientIDs.first
  }
}

extension DMChannel: Decodable {
  public init(from decoder: Decoder) throws {
    id = try decoder.decode("id")
    lastMessageID = try decoder.decodeIfPresent("last_message_id")
    recipientIDs = try decoder.decode("recipient_ids")
  }
}
