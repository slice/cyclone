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

    applySnapshot(snapshot, scrolling: .toBottom)
  }

  /// Prepends old messages to the view controller.
  public func prependOldMessages(_ messagesNewestFirst: [Message]) {
    var snapshot = dataSource.snapshot()

    guard !messages.isEmpty else {
      fatalError("there are no messages being displayed, so we cannot prepend")
    }

    guard !messagesNewestFirst.isEmpty else {
      fatalError("messages to prepend was empty")
    }

    let messages: [Message] = messagesNewestFirst.reversed()

    if snapshot.sectionIdentifiers.isEmpty {
      // if we have no section identifiers, just apply the messages as if they
      // were an initial listing
      applyInitialMessages(messages)
      return
    }

    let firstSection = snapshot.sectionIdentifiers.first!
    let firstMessage = messages.first!
    var section = MessagesSection(firstMessage: firstMessage)
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
    // effective scroll position to prevent this by adding the new height.
    applySnapshot(snapshot, scrolling: .addingHeightDifference)
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

    // Because the newly received message would be below the clip view, restore
    // the saved scroll position without performing additional calculations.
    applySnapshot(snapshot, scrolling: .usingSavedPosition)
  }

  private func applySnapshot(
    _ snapshot: MessagesSnapshot,
    scrolling scrollingBehavior: ScrollingBehavior,
    completion: (() -> Void)? = nil
  ) {
    let scrolledToBottom = scrollView.isScrolledToBottom

    // If we're scrolled to the bottom, pin the scroll view to the bottom.
    preserveScrollPosition(by: scrolledToBottom ? .toBottom : scrollingBehavior) { restoreScrollPosition in
      self.dataSource.apply(snapshot, animatingDifferences: false) {
        restoreScrollPosition()
        completion?()
      }
    }
  }
}
