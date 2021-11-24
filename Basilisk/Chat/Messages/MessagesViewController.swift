import Cocoa
import Combine
import Contempt
import FineJSON

private extension NSScrollView {
  var isScrolledToBottom: Bool {
    let clipView = contentView
    let documentView = documentView!
    let isScrolledToBottom = clipView.bounds.origin.y + clipView.bounds
      .height == documentView.frame.height
    return isScrolledToBottom
  }

  func scrollToEnd() {
    let totalHeight = documentView!.frame.height
    let clipViewHeight = contentView.bounds.height
    contentView.scroll(to: NSPoint(x: 0.0, y: totalHeight - clipViewHeight))
  }

  var scrollPercentage: Double {
    contentView.bounds
      .minY / (documentView!.frame.height - contentView.bounds.height)
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

private typealias MessagesDiffableDataSource =
  NSCollectionViewDiffableDataSource<
    MessagesSection,
    Message.ID
  >
private typealias MessagesSnapshot =
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
  @IBOutlet var collectionView: NSCollectionView!

  private static let messageGroupHeaderKind = "message-group-header"

  /// The array of messages this view controller is showing, ordered from oldest
  /// to newest.
  private var messages: [Message] = []

  /// The ID of the oldest message this view controller is showing.
  public var oldestMessageID: Message.ID? {
    messages.first?.id
  }

  /// Called when the user tries to invoke a command.
  var onRunCommand: ((_ command: String, _ arguments: [String]) -> Void)?

  /// Called when the user tries to send a message.
  var onSendMessage: ((_ content: String) -> Void)?

  /// Called when the user scrolls near the top of the message history.
  var onScrolledNearTop: (() -> Void)?

  private var dataSource: MessagesDiffableDataSource!
  private var clipViewBoundsChangedSink: AnyCancellable!

  override func viewDidLoad() {
    super.viewDidLoad()

    dataSource =
      MessagesDiffableDataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, identifier in
        guard let self = self else { return nil }

        let item = collectionView.makeItem(
          withIdentifier: .message,
          for: indexPath
        ) as! MessageCollectionViewItem

        guard let message = self.messages.first(where: { $0.id == identifier })
        else {
          fatalError("tried to make item for message not present in state")
        }

        item.contentTextField.stringValue = message.content
        return item
      }

    dataSource
      .supplementaryViewProvider =
      { [weak self] collectionView, _, indexPath -> (
        NSView & NSCollectionViewElement
      ) in
        guard let self = self else { return MessageGroupHeader() }

        let supplementaryView = collectionView.makeSupplementaryView(
          ofKind: Self.messageGroupHeaderKind,
          withIdentifier: .messageGroupHeader,
          for: indexPath
        ) as! MessageGroupHeader
        let dataSource = collectionView
          .dataSource as! MessagesDiffableDataSource

        let currentSnapshot = dataSource.snapshot()

        // grab the current message group (section) we're in; it references the
        // author id of this message group
        let section = currentSnapshot.sectionIdentifiers[indexPath.section]

        guard let user = self.messages
          .first(where: { $0.author.id == section.authorID })?.author
        else {
          fatalError("unable to find a message in state with the user")
        }
        let name = "\(user.username)#\(user.discriminator)"

        supplementaryView.groupAuthorTextField.stringValue = name

        if let avatar = user.avatar {
          Task {
            let url = avatar.url(withFileExtension: "png")
            let image = try await ImageCache.shared.image(at: url)
            supplementaryView.groupAvatarRounding.radius = 10.0
            supplementaryView.groupAvatarImageView.image = image
          }
        }

        return supplementaryView
      }

    let messageNib = NSNib(nibNamed: "MessageCollectionViewItem", bundle: nil)
    collectionView.register(messageNib, forItemWithIdentifier: .message)

    let messageGroupHeaderNib = NSNib(
      nibNamed: "MessageGroupHeader",
      bundle: nil
    )
    collectionView.register(
      messageGroupHeaderNib,
      forSupplementaryViewOfKind: Self.messageGroupHeaderKind,
      withIdentifier: .messageGroupHeader
    )

    collectionView.dataSource = dataSource
    collectionView.collectionViewLayout = makeCollectionViewLayout()

    let clipView = scrollView.contentView
    clipView.postsBoundsChangedNotifications = true
    clipViewBoundsChangedSink = NotificationCenter.default.publisher(
      for: NSView.boundsDidChangeNotification,
      object: clipView
    )
    .throttle(for: .seconds(5), scheduler: RunLoop.main, latest: true)
    .sink { [weak self] _ in
      guard let self = self else { return }
      if self.scrollView.scrollPercentage < 0.25 {
        self.onScrolledNearTop?()
      }
    }
  }

  /// Applies an array of initial `Message` objects to be displayed in the view
  /// controller.
  ///
  /// The most recent messages should be first.
  public func applyInitialMessages(_ messages: [Message]) {
    var snapshot = NSDiffableDataSourceSnapshot<MessagesSection, Message.ID>()

    guard !messages.isEmpty else {
      self.messages = []
      dataSource.apply(snapshot)
      return
    }

    // reverse the messages so that the oldest ones come first, so we can get
    // the intended ui (bottom of scroll view is where the latest messages are)
    let reversedMessages: [Message] = messages.reversed()
    self.messages = reversedMessages

    let firstMessage = reversedMessages.first!
    var currentSection = MessagesSection(firstMessage: firstMessage)
    snapshot.appendSections([currentSection])
    for message in reversedMessages {
      if message.author.id != currentSection.authorID {
        // author has changed, so create a new section (message group)
        currentSection = MessagesSection(firstMessage: message)
        snapshot.appendSections([currentSection])
      }

      // keep on appending items (messages) to this section until the author
      // changes
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
    messages.append(message)
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
      self.applyInitialMessages(messages)
      return
    }

    let firstSection = snapshot.sectionIdentifiers.first!
    var section = MessagesSection(firstMessage: messages.first!)
    snapshot.insertSections([section], beforeSection: firstSection)
    for message in messages {
      if message.author.id != section.authorID {
        // author differs, start a new message group
        let newSection = MessagesSection(firstMessage: message)
        snapshot.insertSections([newSection], afterSection: section)
        section = newSection
      }

      snapshot.appendItems([message.id], toSection: section)
    }

    self.messages.insert(contentsOf: messages, at: 0)
    applySnapshot(snapshot)
  }

  private func applySnapshot(
    _ snapshot: MessagesSnapshot,
    alwaysScrollToBottom: Bool = false
  ) {
    let wasScrolledToBottom = alwaysScrollToBottom ? true : scrollView
      .isScrolledToBottom
    dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
      if wasScrolledToBottom {
        self?.scrollView.scrollToEnd()
      }
    }
  }

  private func makeCollectionViewLayout() -> NSCollectionViewLayout {
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .fractionalHeight(1.0)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)

    let group = NSCollectionLayoutGroup.vertical(
      layoutSize: .init(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .estimated(20.0)
      ),
      subitems: [item]
    )
    group.contentInsets = .init(top: 0, leading: 10.0, bottom: 0, trailing: 0)

    let section = NSCollectionLayoutSection(group: group)
    let messageGroupHeader = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: .init(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .absolute(30.0)
      ),
      elementKind: Self.messageGroupHeaderKind,
      alignment: .top
    )
    section.boundarySupplementaryItems = [messageGroupHeader]

    return NSCollectionViewCompositionalLayout(section: section)
  }

  func appendToConsole(line _: String) {
//    consoleTextView.string += line + "\n"
//
//    if consoleScrollView.isScrolledToBottom {
//      consoleTextView.scrollToEndOfDocument(self)
//    }
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
}
