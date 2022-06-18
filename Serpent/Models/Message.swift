public struct Message: Identifiable {
  public var id: Snowflake
  public var content: String
  public var author: User
  public var attachments: [Attachment]

  public init(id: Snowflake, content: String, author: User) {
    self.id = id
    self.content = content
    self.author = author
    self.attachments = []
  }
}

extension Message: Hashable {
  public static func ==(lhs: Message, rhs: Message) -> Bool {
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
  }
}
