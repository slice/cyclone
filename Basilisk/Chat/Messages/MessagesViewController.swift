import Cocoa
import Combine
import Contempt
import CoreImage
import CoreImage.CIFilterBuiltins
import os.log
import OrderedCollections
import Kingfisher

private extension NSScrollView {
  var scrollPosition: CGFloat {
    return contentView.bounds.origin.y
  }

  var isScrolledToBottom: Bool {
    return scrollPosition + contentView.bounds.height == documentView!.frame.height
  }

  func scrollToEnd() {
    let totalHeight = documentView!.frame.height
    let clipViewHeight = contentView.bounds.height
    contentView.scroll(to: NSPoint(x: 0.0, y: totalHeight - clipViewHeight))
  }

  var scrollPercentage: Double {
    return contentView.bounds.minY / (documentView!.frame.height - contentView.bounds.height)
  }
}

struct MessagesSection: Hashable {
  let authorID: User.ID
  let firstMessageID: Message.ID

  init(firstMessage: Message) {
    authorID = firstMessage.author.id
    firstMessageID = firstMessage.id
  }
}

typealias MessagesDiffableDataSource =
  NSTableViewDiffableDataSource<
    MessagesSection,
    Message.ID
  >

typealias MessagesSnapshot =
  NSDiffableDataSourceSnapshot<
    MessagesSection,
    Message.ID
  >

private extension NSUserInterfaceItemIdentifier {
  static let message: Self = .init("message")
  static let messageGroupHeader: Self = .init("message-group-header")
}

class MessagesViewController: NSViewController {
  @IBOutlet var scrollView: NSScrollView!
  @IBOutlet var tableView: NSTableView!

  /// The ordered set of messages this view controller is showing, ordered from
  /// oldest to newest.
  var messages: OrderedDictionary<Message.ID, Message> = [:]

  /// The ID of the oldest message this view controller is showing.
  public var oldestMessageID: Message.ID? { messages.elements[0].value.id }

  /// Called when the user tries to invoke a command.
  var onRunCommand: ((_ command: String, _ arguments: [String]) -> Void)?

  /// Called when the user tries to send a message.
  var onSendMessage: ((_ content: String) -> Void)?

  /// Called when the user scrolls near the top of the message history.
  var onScrolledNearTop: (() -> Void)?

  /// A message view that is used to measure message heights. It is never
  /// drawn to the screen.
  private var messageSizingTemplate: MessageRow!
  private var groupRowHeight: CGFloat!

  private var dataSource: MessagesDiffableDataSource!
  private var clipViewBoundsChangedSink: AnyCancellable!

  var signposter = OSSignposter()

  override func viewDidLoad() {
    super.viewDidLoad()

    self.groupRowHeight = 45.0

    dataSource =
      MessagesDiffableDataSource(tableView: tableView) { [weak self] tableView, tableColumn, _, snowflake in
        guard let self = self else { return .init(frame: .zero) }

        let item = tableView.makeView(withIdentifier: .message, owner: nil) as! MessageRow

        guard let message = self.messages[snowflake] else {
          NSLog("tried to make item for message not present in state")
          return .init(frame: .zero)
        }

        item.configure(withMessage: message)
        return item
      }

    dataSource.sectionHeaderViewProvider = { [weak self] collectionView, row, section in
      guard let self = self else { return .init(frame: .zero) }
      let item = self.tableView.makeView(withIdentifier: .messageGroupHeader, owner: nil) as! MessageGroupHeader
      let message = self.messages[section.firstMessageID]!
      item.groupAuthorTextField.stringValue = message.author.username
      item.groupAvatarRounding.radius = 10.0
      if let avatar = message.author.avatar {
        item.groupAvatarImageView.kf.setImage(with: avatar.url(withFileExtension: "png"))
      }
      item.groupTimestampTextField.stringValue = message.id.timestamp.formatted(date: .omitted, time: .shortened)
      return item
    }

    tableView.dataSource = dataSource
    tableView.delegate = self
    tableView.register(MessageRow.nib!, forIdentifier: .message)
    tableView.register(MessageGroupHeader.nib!, forIdentifier: .messageGroupHeader)

    self.messageSizingTemplate = (tableView.makeView(withIdentifier: .message, owner: nil)! as! MessageRow)

    let clipView = scrollView.contentView
    clipView.postsBoundsChangedNotifications = true
    clipViewBoundsChangedSink = NotificationCenter.default.publisher(
      for: NSView.boundsDidChangeNotification,
      object: clipView
    )
    .sink { [weak self] _ in
      guard let self = self else { return }
      if self.scrollView.scrollPercentage < 0.25 {
        self.onScrolledNearTop?()
      }
    }
  }

  // MARK: - Applying Messages

  /// Applies an array of initial `Message` objects to be displayed in the
  /// view controller.
  ///
  /// The most recent messages should appear first.
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

  /// Appends a newly received message to the view controller and updates the
  /// UI accordingly.
  public func appendNewlyReceivedMessage(_ message: Message) {
    var snapshot = dataSource.snapshot()

    var lastSection = snapshot.sectionIdentifiers.last

    if lastSection?.authorID != message.author.id || lastSection == nil {
      // author differs or this is the first message, we should start a new
      // message group
      lastSection = MessagesSection(firstMessage: message)
      snapshot.appendSections([lastSection!])
    }

    snapshot.appendItems([message.id], toSection: lastSection!)

    messages[message.id] = message
    applySnapshot(snapshot)
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

    let scrollView = tableView.enclosingScrollView!
    let savedScrollPosition = scrollView.scrollPosition
    let savedContentHeight = scrollView.documentView!.bounds.height
    applySnapshot(snapshot) {
      // when prepending messages, the scroll view ends up becoming positioned
      // in a similarly to where it was before we prepended the messages
      // at all. i.e. if you are near the top, after we prepend a chunk of
      // messages, we will still be near the top. thus, all of the messages
      // that were previously onscreen will all move downwards and offscreen
      // after prepending.
      //
      // to prevent loading messages infinitely when we scroll near the
      // top of the message view, reposition the scroll view to be near the
      // oldest messages onscreen from before the load. this just "feels better",
      // too.
      let newHeight = scrollView.documentView!.bounds.height
      guard newHeight != savedContentHeight else {
        NSLog("[warning] no height was added after prepending older messages, this should never happen")
        return
      }

      let newPosition = (newHeight - savedContentHeight) + savedScrollPosition
      scrollView.contentView.scroll(to: NSPoint(x: 0.0, y: newPosition))
      NSLog("adjusting scroll offset from \(savedScrollPosition) to \(newPosition)")
    }
  }

  private func applySnapshot(_ snapshot: MessagesSnapshot,
                             alwaysScrollToBottom: Bool = false,
                             completion: (() -> Void)? = nil) {
    let wasScrolledToBottom = alwaysScrollToBottom ? true : scrollView
      .isScrolledToBottom
    dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
      if wasScrolledToBottom {
        self?.scrollView.scrollToEnd()
      }
      completion?()
    }
  }

  func appendToConsole(line _: String) {
    // TODO(skip): add a virtual message
  }

  @IBAction func inputTextFieldAction(_ sender: NSTextField) {
    let fieldText = sender.stringValue
    sender.stringValue = ""

    guard !fieldText.isEmpty else { return }

    if fieldText.starts(with: "/") {
      let tokens = fieldText.trimmingCharacters(in: .whitespacesAndNewlines)
        .split(separator: " ")
      let firstToken = tokens.first!
      let firstTokenWithoutSlash =
        firstToken[firstToken.index(after: firstToken.startIndex) ..< firstToken
          .endIndex]

      onRunCommand?(
        String(firstTokenWithoutSlash),
        tokens.dropFirst().map(String.init)
      )
      return
    }

    onSendMessage?(fieldText)
  }

  private func measureRowHeight(forMessage message: Message) -> Double {
    messageSizingTemplate.prepareForReuse()
    messageSizingTemplate.configure(withMessage: message, forMeasurements: true)
    return messageSizingTemplate.fittingSize.height
  }
}

extension MessagesViewController: NSTableViewDelegate {
  func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
    if case .some(_) = dataSource.sectionIdentifier(forRow: row) {
      return self.groupRowHeight
    }
    let messageID = dataSource.itemIdentifier(forRow: row)!
    let message = self.messages[messageID]!
    return measureRowHeight(forMessage: message)
  }
}
