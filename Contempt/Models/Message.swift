import GenericJSON

public struct Message: Identifiable {
  public let id: Snowflake
  public let content: String
  public let author: User

  public init(json: JSON) {
    let object = json.objectValue!
    id = Snowflake(string: object["id"]!.stringValue!)
    content = object["content"]!.stringValue!
    author = User(json: object["author"]!)
  }

  public init(id: Snowflake, content: String, author: User) {
    self.id = id
    self.content = content
    self.author = author
  }
}
