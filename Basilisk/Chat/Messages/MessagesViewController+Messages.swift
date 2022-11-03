import Cocoa
import OrderedCollections
import Serpent

enum ScrollingBehavior {
  /// Preserves the scroll position by summing the added height of the scroll
  /// view's content view with the saved scroll position.
  case addingHeightDifference

  /// Preserves the scroll position by setting it back to the saved value.
  case usingSavedPosition

  /// Always scrolls to the bottom.
  case toBottom
}

extension MessagesViewController {
  /// Iterates through an array of messages, inserting message headers as
  /// necessary.
  ///
  /// Older messages should come first in the array.
  func discoverMessageHeaders(_ messages: some Collection<Message>, insertFirstMessage: Bool = false) {
    guard let firstMessage = messages.first else {
      fatalError("tried to discover message headers with an empty array")
    }
    var currentAuthor = firstMessage.author.id

    if insertFirstMessage {
      messageHeaders.insert(firstMessage.id)
    }

    for message in messages {
      if message.author.id != currentAuthor || message.reference != nil {
        // author has changed, so create a new section (message group)
        messageHeaders.insert(message.id)
        currentAuthor = message.author.id
      }
    }
  }

  /// Invalidate the entire row height cache of the table view.
  func invalidateEntireRowHeightCache() {
    NSAnimationContext.beginGrouping()
    NSAnimationContext.current.duration = 0
    let entireTableView: IndexSet = .init(0 ..< self.tableView.numberOfRows)
    self.tableView.noteHeightOfRows(withIndexesChanged: entireTableView)
    NSAnimationContext.endGrouping()
  }

  /// Applies an array of initial `Message` objects to be displayed in the
  /// view controller.
  ///
  /// The most recent messages should come first in the array.
  func applyInitialMessages(_ messages: [Message]) {
    defer {
      self.tableView.reloadData()

      // macOS 13.0 has a bug where the row height cache is not invalidated
      // after you call `reloadData`, which causes scrolling to jump around.
      //
      // You'd think to call this before we touch `self.messages` and the table
      // view itself, but that doesn't seem to work around the problem?
      if #unavailable(macOS 13.1) {
        self.invalidateEntireRowHeightCache()
      }

      self.scrollView.scrollToEnd()
    }

    if messages.isEmpty {
      self.messages = [:]
      return
    }

    messageHeaders = []

    // Make older messages come first. This is how we'll store it internally,
    // and it's also the order desired by the table view (we want recent
    // messages to appear at the bottom).
    let reversedMessages = messages.reversed()
    discoverMessageHeaders(reversedMessages, insertFirstMessage: true)

    self.messages = OrderedDictionary(
      reversedMessages.map { message in (message.id, message) },
      uniquingKeysWith: { left, _ in left }
    )
  }

  /// Prepends old messages to the view controller.
  func prependOldMessages(_ historyNewestFirst: [Message]) {
    guard !messages.isEmpty else {
      fatalError("there are no messages being displayed, so we cannot prepend")
    }

    guard !historyNewestFirst.isEmpty else {
      fatalError("messages to prepend was empty")
    }

    let history: [Message] = historyNewestFirst.reversed()

    for message in historyNewestFirst {
      self.messages.updateValue(message, forKey: message.id, insertingAt: 0)
    }

    // TODO: Remove the first message as a header if the newest message in
    // the history is the same author.
    let insertFirstMessage = self.messages.elements.first!.value.author.id != history.first!.author.id
    discoverMessageHeaders(history, insertFirstMessage: insertFirstMessage)

    let indexSet: IndexSet = .init(integersIn: 0 ..< history.count)

    // When loading older messages, the loaded messages end up pushing the
    // messages that are currently onscreen downwards. Not only is this visually
    // disorienting, but it can cause the an infinite loop of loading new
    // messages as the scroll position is still near the top. Preserve the
    // effective scroll position to prevent this by adding the new height.
    self.preserveScrollPosition(by: .addingHeightDifference) { restore in
      self.tableView.insertRows(at: indexSet)
      restore()
    }
  }

  /// Appends a newly received message to the view controller.
  func appendNewlyReceivedMessage(_ message: Message) {
    if messages.elements.last?.value.author.id != message.author.id || message.reference != nil {
      messageHeaders.insert(message.id)
    }

    messages[message.id] = message

    preserveScrollPosition(by: scrollView.isScrolledToBottom ? .toBottom : .usingSavedPosition) { [unowned self] restore in
      tableView.insertRows(at: [tableView.numberOfRows], withAnimation: [])
      restore()
    }
  }
}
