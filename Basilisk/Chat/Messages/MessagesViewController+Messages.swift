import Cocoa
import Serpent
import OrderedCollections

extension MessagesViewController {
  /// Applies an array of initial `Message` objects to be displayed in the
  /// view controller.
  ///
  /// The most recent messages should come first in the array.
  public func applyInitialMessages(_ messages: [Message]) {
    var snapshot = NSDiffableDataSourceSnapshot<MessagesSection, Message.ID>()

    if messages.isEmpty {
      self.messages = [:]
      dataSource.apply(snapshot, animatingDifferences: false)
      return
    }

    // We want the recent messages to appear at the bottom of the scroll view,
    // so we have to reverse the array here.
    self.messages = OrderedDictionary(
      messages.map { message in (message.id, message) }.reversed(),
      uniquingKeysWith: { (left, right) in left }
    )

    let firstMessage = self.messages.elements[0].value
    var currentSection = MessagesSection(firstMessage: firstMessage)
    snapshot.appendSections([currentSection])

    for message in self.messages.values {
      if message.author.id != currentSection.authorID {
        // author has changed, so create a new section (message group)
        currentSection = MessagesSection(firstMessage: message)
        snapshot.appendSections([currentSection])
      }

      snapshot.appendItems([message.id], toSection: currentSection)
    }

    applySnapshot(snapshot, alwaysScrollToBottom: true)
  }

  /// Prepends old messages to the view controller.
  public func prependOldMessages(_ messagesNewestFirst: [Message]) {
    var snapshot = dataSource.snapshot()

    guard !messages.isEmpty else { return }

    let messages: [Message] = messagesNewestFirst.reversed()

    if snapshot.sectionIdentifiers.isEmpty {
      // if we have no section identifiers, just apply the messages as if they
      // were an initial listing
      applyInitialMessages(messages)
      return
    }

    let firstSection = snapshot.sectionIdentifiers.first!
    var section = MessagesSection(firstMessage: messages.first!)
    snapshot.insertSections([section], beforeSection: firstSection)

    for message in messages {
      if message.author.id != section.authorID {
        // author differs, start a new message group
        let newSection = MessagesSection(firstMessage: message)
        if snapshot.sectionIdentifiers.contains(newSection) {
          fatalError("\(newSection) was already in the snapshot -- this should never happen")
        }
        snapshot.insertSections([newSection], afterSection: section)
        section = newSection
      }

      snapshot.appendItems([message.id], toSection: section)
    }

    for message in messagesNewestFirst {
      self.messages.updateValue(message, forKey: message.id, insertingAt: 0)
    }

    // When loading older messages, the loaded messages end up pushing the
    // messages that are currently onscreen downwards. Not only is this visually
    // disorienting, but it can cause the an infinite loop of loading new
    // messages as the scroll position is still near the top. Preserve the
    // scroll position to prevent this.
    preserveScrollPosition {
      self.applySnapshot(snapshot)
    }
  }

  /// Appends a newly received message to the view controller.
  public func appendNewlyReceivedMessage(_ message: Message) {
    var snapshot = dataSource.snapshot()

    var lastSection = snapshot.sectionIdentifiers.last

    if lastSection?.authorID != message.author.id || lastSection == nil {
      // If the author is different or this is the first message, we should
      // begin a new message group.
      lastSection = MessagesSection(firstMessage: message)
      snapshot.appendSections([lastSection!])
    }

    snapshot.appendItems([message.id], toSection: lastSection!)

    messages[message.id] = message
    applySnapshot(snapshot)
  }

  private func applySnapshot(_ snapshot: MessagesSnapshot,
    alwaysScrollToBottom: Bool = false,
    completion: (() -> Void)? = nil
  ) {
    let scrolledToBottom = scrollView.isScrolledToBottom
    dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
      if alwaysScrollToBottom || scrolledToBottom {
        self?.scrollView.scrollToEnd()
      }
      completion?()
    }
  }
}
