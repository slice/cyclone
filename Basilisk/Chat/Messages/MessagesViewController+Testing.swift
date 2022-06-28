import Serpent

extension MessagesViewController {
  /// Populate the view with randomly generated sample messages.
  func applySampleData() {
    let authors = [
      User(fakeWithName: "foo", id: 1),
      User(fakeWithName: "bar", id: 2),
      User(fakeWithName: "baz", id: 3),
      User(fakeWithName: "quux", id: 4),
    ]

    func messageContent() -> String {
      let segments = ["hello", "こんにちは", "🦎", "taco", "burrito", "nachos"]
      var content = ""
      for _ in 0...((5...30).randomElement()!) {
        content += segments.randomElement()!
        content += (0...10).randomElement()! > 8 ? "\n" : " "
      }
      return content
    }

    let messages: [Message] = stride(from: 0, to: 1000, by: 1).map { n in
      var message = Message(
        id: Snowflake(uint64: UInt64(100 + n)),
        content: messageContent(),
        author: authors[(n / 5) % authors.count]
      )
      if (0...10).randomElement()! == 5 {
        message.attachments = Array(
          repeating: Attachment(fakeWithWidth: 640, height: 480),
          count: (1...3).randomElement()!
        )
      }
//      let measurement = self.measureRowHeight(forMessage: message)
//      message.content = "\(measurement) \(message.content)"
      return message
    }

    applyInitialMessages(messages)
  }
}
