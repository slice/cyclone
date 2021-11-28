import Cocoa
import Combine
import Contempt
import CoreImage
import CoreImage.CIFilterBuiltins
import FineJSON
import os.log

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
  NSCollectionViewDiffableDataSource<
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
  @IBOutlet var collectionView: NSCollectionView!

  private static let messageGroupHeaderKind = "message-group-header"
  var cachedMessageSizes: [Message.ID: NSSize] = [:]

  /// The array of messages this view controller is showing, ordered from oldest
  /// to newest.
  var messages: [Message] = []

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

  /// A message view that is used to measure message heights. It is never
  /// drawn to the screen.
  var messageSizingTemplate: MessageCollectionViewItem!

  private var dataSource: MessagesDiffableDataSource!
  private var clipViewBoundsChangedSink: AnyCancellable!

  let horizontalMessageSectionInset = 11.0

  var signposter = OSSignposter()

  override func viewDidLoad() {
    super.viewDidLoad()

    var views: NSArray? = []
    guard MessageCollectionViewItem.nib!
            .instantiate(withOwner: messageSizingTemplate, topLevelObjects: &views) else {
      preconditionFailure("failed to instantiate message sizing template nib")
    }
    let messageSizingTemplate = views?.filter { $0 is MessageCollectionViewItem }.first
    guard let messageSizingTemplate = messageSizingTemplate as? MessageCollectionViewItem else {
      preconditionFailure("failed to locate message sizing template from instantiated nib")
    }
    self.messageSizingTemplate = messageSizingTemplate

    dataSource =
      MessagesDiffableDataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, identifier in
        guard let self = self else { return nil }

        let item = collectionView.makeItem(
          withIdentifier: .message,
          for: indexPath
        ) as! MessageCollectionViewItem

        // TODO(skip): replace this with an O(1) operation.
        guard let message = self.messages.first(where: { $0.id == identifier })
        else {
          fatalError("tried to make item for message not present in state")
        }

        item.configure(withMessage: message)

        return item
      }

    dataSource
      .supplementaryViewProvider =
      { [weak self] collectionView, _, indexPath -> (
        NSView & NSCollectionViewElement
      ) in
        guard let self = self else { return MessageGroupHeader() }

        let supplementaryView = collectionView.makeSupplementaryView(
          ofKind: NSCollectionView.elementKindSectionHeader,
          withIdentifier: .messageGroupHeader,
          for: indexPath
        ) as! MessageGroupHeader
        let dataSource = collectionView
          .dataSource as! MessagesDiffableDataSource

        let currentSnapshot = dataSource.snapshot()

        // grab the current message group (section) we're in; it references the
        // author id of this message group
        let section = currentSnapshot.sectionIdentifiers[indexPath.section]

        guard let message = self.messages
          .first(where: { $0.id == section.firstMessageID })
        else {
          fatalError("unable to find a message in state with the user")
        }
        let user = message.author
        let name = "\(user.username)#\(user.discriminator)"

        supplementaryView.groupAuthorTextField.stringValue = name

        if let task = supplementaryView.avatarLoadingTask {
          task.cancel()
        }

        if let avatar = user.avatar {
          supplementaryView.avatarLoadingTask = Task {
            let url = avatar.url(withFileExtension: "png")
            let image = try await ImageCache.shared.image(at: url)
            supplementaryView.groupAvatarRounding.radius = 10.0
            supplementaryView.groupAvatarImageView.image = image
          }
        }

        supplementaryView.groupTimestampTextField.stringValue = message.id
          .timestamp
          .formatted(.relative(presentation: .named, unitsStyle: .narrow))

        return supplementaryView
      }

    collectionView.register(MessageCollectionViewItem.nib!, forItemWithIdentifier: .message)
    collectionView.register(MessageGroupHeader.nib!,
                            forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
                            withIdentifier: .messageGroupHeader)

    collectionView.dataSource = dataSource
    collectionView.collectionViewLayout = makeCollectionViewLayout()
    collectionView.delegate = self

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

    // immediately invalidate the compositional layout.
    //
    // for some reason, applying the initial batch of messages leaves messages
    // with multiline text awkwardly clipped. this fixes itself when a new
    // message is received, which indirectly invalidates the layout. so, do it
    // now so we get the correct layout ASAP. we are using estimated item
    // dimensions to facilitate variable height items, so it's possible there's
    // some rough edges with this. investigate further?
    collectionView.collectionViewLayout!.invalidateLayout()
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
        snapshot.insertSections([newSection], afterSection: section)
        section = newSection
      }

      snapshot.appendItems([message.id], toSection: section)
    }

    self.messages.insert(contentsOf: messages, at: 0)

    let scrollView = collectionView.enclosingScrollView!
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

  // MARK: - Collection View Layout

  private func makeCollectionViewLayout() -> NSCollectionViewLayout {
    let layout = InvalidatingCollectionViewFlowLayout()
    let spacingBetweenMessages = 5.0
    layout.minimumLineSpacing = spacingBetweenMessages
    layout.minimumInteritemSpacing = 0.0
    // section insets are returned dynamically from the delegate
    layout.scrollDirection = .vertical
    return layout
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
}
