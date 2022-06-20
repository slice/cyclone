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
  static let message: Self = .init("message")
  static let messageGroupHeader: Self = .init("message-group-header")
}

final class MessagesViewController: NSViewController {
  @IBOutlet var scrollView: NSScrollView!
  @IBOutlet var tableView: NSTableView!

  /// The ordered set of messages this view controller is showing, ordered from
  /// oldest to newest.
  public var messages: OrderedDictionary<Message.ID, Message> = [:]

  /// The ID of the oldest message this view controller is showing.
  public var oldestMessageID: Message.ID? { messages.elements[0].value.id }

  /// The delegate of the messages view controller.
  public weak var delegate: MessagesViewControllerDelegate?

  /// A message view that is used to measure message heights. It is never
  /// drawn to the screen.
  var messageSizingTemplate: MessageRow!

  /// The height of group rows, in points.
  static let groupRowHeight: CGFloat = 45.0

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
    tableView.register(MessageRow.nib!, forIdentifier: .message)
    tableView.register(MessageGroupHeader.nib!, forIdentifier: .messageGroupHeader)

    self.messageSizingTemplate =
      (tableView.makeView(withIdentifier: .message, owner: nil)! as! MessageRow)

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

  /// Measures the height of a message as it would appear in the table view.
  func measureRowHeight(forMessage message: Message) -> Double {
    let signpostID = signposter.makeSignpostID()
    let signpostName: StaticString = "Message Height Measurement"
    let state = signposter.beginInterval(signpostName, id: signpostID)

    messageSizingTemplate.prepareForReuse()
    signposter.emitEvent("Prepare for reuse", id: signpostID)
    messageSizingTemplate.configure(withMessage: message, forMeasurements: true)
    signposter.emitEvent("View configuration", id: signpostID)
    let height = messageSizingTemplate.fittingSize.height
    signposter.emitEvent("Measurement", id: signpostID)
    signposter.endInterval(signpostName, state)

    return height
  }
}

extension MessagesViewController: NSTableViewDelegate {
  func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
    if case .some(_) = dataSource.sectionIdentifier(forRow: row) {
      return Self.groupRowHeight
    }
    let messageID = dataSource.itemIdentifier(forRow: row)!
    let message = self.messages[messageID]!
    return measureRowHeight(forMessage: message)
  }
}
