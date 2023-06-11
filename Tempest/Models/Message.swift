public enum MessageReferenceWrapper {
  case none
  indirect case reference(Message)
}

extension MessageReferenceWrapper: Decodable {
  public init(from decoder: Decoder) throws {
    self = try .reference(decoder.decodeSingleValue())
  }
}

public struct Message: Identifiable {
  public var id: Snowflake
  public var content: String
  public var author: User
  public var attachments: [Attachment]

  /// The resolved message object that this message is referencing.
  public var referencedMessage: MessageReferenceWrapper

  /// A reference to another message.
  public var reference: Reference?

  public struct Reference: Decodable {
    public var channelID: Ref<GuildChannel>
    public var guildID: Ref<Guild>?
    public var messageID: Ref<Message>

    public init(from decoder: Decoder) throws {
      channelID = try decoder.decode("channel_id")
      guildID = try decoder.decodeIfPresent("guild_id")
      messageID = try decoder.decode("message_id")
    }
  }

  public init(id: Snowflake, content: String, author: User) {
    self.id = id
    self.content = content
    self.author = author
    self.attachments = []
    self.referencedMessage = .none
    self.reference = nil
  }
}

extension Message: Hashable {
  public static func == (lhs: Message, rhs: Message) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

extension Message: Decodable {
  public init(from decoder: Decoder) throws {
    id = try decoder.decode("id")
    content = try decoder.decode("content")
    author = try decoder.decode("author")
    attachments = try decoder.decodeIfPresent("attachments") ?? []
    referencedMessage = try decoder.decodeIfPresent("referenced_message") ?? .none
    reference = try decoder.decodeIfPresent("message_reference")
  }
}
