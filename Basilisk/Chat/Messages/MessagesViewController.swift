import Cocoa
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import Kingfisher
import OrderedCollections
import Serpent
import os.log

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

extension NSUserInterfaceItemIdentifier {
  static let unifiedMessageRow: Self = .init("unified-message-row")
}

final class MessagesViewController: NSViewController {
  @IBOutlet var scrollView: NSScrollView!
  @IBOutlet var tableView: NSTableView!

  /// The ordered set of messages this view controller is showing, ordered from
  /// oldest to newest.
  public var messages: OrderedDictionary<Message.ID, Message> = [:]

  /// Cached message row heights.
  ///
  /// This is needed in the first place because the table view remeasures the
  /// height of every row upon a reload. We cannot selectively reload by an
  /// index set because we prepend and append frequently, which shifts all of
  /// rows in a direction.
  private var cachedMessageHeights: [Message.ID: Double] = [:]

  /// The ID of the oldest message this view controller is showing.
  public var oldestMessageID: Message.ID? { messages.elements[0].value.id }

  /// The delegate of the messages view controller.
  public weak var delegate: MessagesViewControllerDelegate?

  /// A message view that is used to measure message heights. It is never
  /// drawn to the screen.
  var messageSizingTemplate: UnifiedMessageRow!

  var dataSource: MessagesDiffableDataSource!
  var clipViewBoundsChangedSink: AnyCancellable!

  let log = Logger(subsystem: "zone.slice.Basilisk", category: "messages-view-controller")
  lazy var signposter = {
    OSSignposter(logger: log)
  }()

  override func viewDidLoad() {
    super.viewDidLoad()

    setupDataSource()

    tableView.delegate = self
    tableView.register(UnifiedMessageRow.nib!, forIdentifier: .unifiedMessageRow)

    self.messageSizingTemplate =
      (tableView.makeView(withIdentifier: .unifiedMessageRow, owner: nil)! as! UnifiedMessageRow)

    let clipView = scrollView.contentView
    clipView.postsBoundsChangedNotifications = true
    clipViewBoundsChangedSink = NotificationCenter.default.publisher(
      for: NSView.boundsDidChangeNotification,
      object: clipView
    )
    .sink { [weak self] _ in
      guard let self = self else { return }
      if self.scrollView.scrollPercentage < 0.25 {
        self.delegate?.messagesControllerDidScrollNearTop(self)
      }
    }

    if UserDefaults.standard.bool(forKey: "BSLKApplySampleMessages") {
      applySampleData()
    }
  }

  /// Returns a Boolean indicating whether a message is the first in a section
  /// (should be displayed with an avatar, name, and timestamp).
  func messageIsFirstInSection(id: Message.ID) -> Bool {
    guard let section = dataSource.snapshot().sectionIdentifier(containingItem: id) else {
      fatalError("failed to get section containing message \(id), while checking if it's first in the section")
    }
    return section.firstMessageID == id
  }

  /// Make changes to the scroll view while preserving what messages are
  /// currently onscreen.
  ///
  /// Before the closure is called, the scroll position of the scroll view will
  /// be saved. It will be restored after the closure returns, accounting for
  /// any possible changes in the content height.
  func preserveScrollPosition(by behavior: ScrollingBehavior,
                              whileMakingChanges changes: @escaping (@escaping (() -> Void)) -> Void) {
    let scrollView = tableView.enclosingScrollView!
    let savedScrollPosition = scrollView.scrollPosition
    let savedContentHeight = scrollView.documentView!.bounds.height

    changes({
      let newHeight = scrollView.documentView!.bounds.height
      guard newHeight != savedContentHeight else {
        self.log.warning("the height didn't change after making changes")
        return
      }

      let newPosition: Double

      switch behavior {
      case .addingHeightDifference:
        // Scroll to where we were before, but also accounting for the new
        // messages at the top.
        newPosition = savedScrollPosition + (newHeight - savedContentHeight)
      case .usingSavedPosition:
        // Scroll to where we were before.
        newPosition = savedScrollPosition
      case .toBottom:
        // Scroll to the bottom of the scroll view.
        newPosition = newHeight - scrollView.contentView.bounds.height
      }

      scrollView.contentView.scroll(to: NSPoint(x: 0.0, y: newPosition))
      scrollView.reflectScrolledClipView(scrollView.contentView)

      self.log.debug("adjusting scroll position (saved: \(savedScrollPosition), current: \(scrollView.scrollPosition)) to \(newPosition) (by: \(String(describing: behavior)))")
    })
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
      let command = String(firstToken.dropFirst(1))

      delegate?.messagesController(
        self, commandInvoked: command,
        arguments: tokens.dropFirst().map(String.init))
      return
    }

    delegate?.messagesController(self, messageSent: fieldText)
  }

  /// Removes a cached row height for a message with a certain ID.
  func invalidateCachedRowHeight(forMessageWithID messageID: Message.ID) {
    cachedMessageHeights.removeValue(forKey: messageID)
  }

  /// Measures the height of a message as it would appear in the table view.
  ///
  /// The result is cached for performance. To invalidate message heights (such
  /// as in the event of a message edit, see ``invalidateCachedRowHeight(forMessageWithID:)``.
  func measureRowHeight(forMessage message: Message) -> Double {
    if let cachedMessageHeight = cachedMessageHeights[message.id] {
      return cachedMessageHeight
    }

    let signpostID = signposter.makeSignpostID()
    let state = signposter.beginInterval("Message Row Height Measurement", id: signpostID)

    messageSizingTemplate.prepareForReuse()
    signposter.emitEvent("Reuse preparation complete", id: signpostID)
    messageSizingTemplate.configure(withMessage: message, isGroupHeader: messageIsFirstInSection(id: message.id), forMeasurements: true)
    signposter.emitEvent("View configuration complete", id: signpostID)
    let height = messageSizingTemplate.fittingSize.height
    cachedMessageHeights[message.id] = height
    signposter.emitEvent("Measurement complete", id: signpostID)
    signposter.endInterval("Message Row Height Measurement", state)

    return height
  }
}

extension MessagesViewController: NSTableViewDelegate {
  func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
    let messageID = dataSource.itemIdentifier(forRow: row)!
    let message = self.messages[messageID]!
    return measureRowHeight(forMessage: message)
  }
}
