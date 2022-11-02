import Cocoa
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import Kingfisher
import OrderedCollections
import os.log
import Serpent

extension NSUserInterfaceItemIdentifier {
  static let unifiedMessageRow: Self = .init("unified-message-row")
}

final class MessagesViewController: NSViewController {
  @IBOutlet var scrollView: NSScrollView!
  @IBOutlet var tableView: NSTableView!
  @IBOutlet var messageInputField: NSTextField!

  /// The ordered dictionary of messages this view controller is showing,
  /// ordered from oldest to newest.
  public var messages: OrderedDictionary<Message.ID, Message> = [:]

  /// The set of messages that are the first in their group.
  ///
  /// When these messages are rendered, the message author and timestamp should
  /// be displayed.
  var messageHeaders: Set<Message.ID> = []

  /// Cached message row heights.
  ///
  /// This is needed in the first place because the table view remeasures the
  /// height of every row upon a reload. We cannot selectively reload by an
  /// index set because we prepend and append frequently, which shifts all of
  /// rows in a direction.
  var cachedMessageHeights: [Message.ID: Double] = [:]

  /// The ID of the oldest message this view controller is showing.
  public var oldestMessageID: Message.ID? { messages.elements[0].value.id }

  /// The delegate of the messages view controller.
  public weak var delegate: MessagesViewControllerDelegate?

  /// A message view that is used to measure message heights. It is never
  /// drawn to the screen.
  var messageSizingTemplate: UnifiedMessageRow!

  var clipViewBoundsChangedSink: AnyCancellable!

  // State for tracking the frame of the table view. Needed because invalidating
  // cached message heights is necessary due to wrapping.
  var tableViewFrameChangedSink: AnyCancellable!
  var lastKnownTableViewFrame: NSRect?

  var messageInputFieldTextChangedSink: AnyCancellable!

  let log = Logger(subsystem: "zone.slice.Basilisk", category: "messages-view-controller")
  lazy var signposter = OSSignposter(logger: log)

  override func viewDidLoad() {
    super.viewDidLoad()

    setupDataSource()

    tableView.delegate = self
    tableView.register(UnifiedMessageRow.nib!, forIdentifier: .unifiedMessageRow)

    messageSizingTemplate =
      (tableView.makeView(withIdentifier: .unifiedMessageRow, owner: nil)! as! UnifiedMessageRow)

    scrollView.applyInnerInsets(bottom: 10)

    tableView.postsFrameChangedNotifications = true
    tableViewFrameChangedSink = NotificationCenter.default.publisher(
      for: NSView.frameDidChangeNotification,
      object: tableView
    ).sink { [unowned self] _ in
      guard let lastKnownTableViewFrame,
            lastKnownTableViewFrame.width != tableView.frame.width
      else {
        lastKnownTableViewFrame = tableView.frame
        return
      }

      let lastKnownString = String(describing: lastKnownTableViewFrame)
      let currentString = String(describing: tableView.frame)
      log.debug("horizontal window resize occurred from \(lastKnownString, privacy: .public) to \(currentString, privacy: .public); invalidating \(self.cachedMessageHeights.count, privacy: .public) cached message heights")

      // Delete all cached message heights.
      //
      // What happens now? Well, we fall back to the table view's internal
      // height cache. This should be fine, but in the future we should really
      // find a way to make this more robust.
      cachedMessageHeights = [:]

      self.lastKnownTableViewFrame = tableView.frame
    }

    let clipView = scrollView.contentView
    clipView.postsBoundsChangedNotifications = true
    clipViewBoundsChangedSink = NotificationCenter.default.publisher(
      for: NSView.boundsDidChangeNotification,
      object: clipView
    )
    .sink { [unowned self] _ in
      if self.scrollView.scrollPercentage < 0.25 {
        self.delegate?.messagesControllerDidScrollNearTop(self)
      }
    }

    if UserDefaults.standard.bool(forKey: "BSLKApplySampleMessages") {
      applySampleData()
    }

    messageInputFieldTextChangedSink = NotificationCenter.default
      .publisher(for: NSControl.textDidChangeNotification, object: messageInputField)
      .sink { [unowned self] notification in
        self.delegate?.messagesControllerMessageInputFieldDidChange(self, notification: notification)
      }
  }

  /// Returns a Boolean indicating whether a message is the first in a section
  /// (should be displayed with an avatar, name, and timestamp).
  func messageIsFirstInSection(id: Message.ID) -> Bool {
    messageHeaders.contains(id)
  }

  /// Make changes to the scroll view while preserving what messages are
  /// currently onscreen.
  ///
  /// Before the closure is called, the scroll position of the scroll view will
  /// be saved. It will be restored after the closure returns, accounting for
  /// any possible changes in the content height.
  func preserveScrollPosition(by behavior: ScrollingBehavior,
                              whileMakingChanges changes: @escaping (@escaping (() -> Void)) -> Void)
  {
    let scrollView = tableView.enclosingScrollView!
    let savedScrollPosition = scrollView.scrollPosition
    let savedContentHeight = scrollView.documentView!.bounds.height

    changes {
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
        newPosition = scrollView.bottomYCoordinate
      }

      scrollView.contentView.scroll(to: NSPoint(x: 0.0, y: newPosition))
      scrollView.reflectScrolledClipView(scrollView.contentView)

      self.log.debug("adjusting scroll position (saved: \(savedScrollPosition), current: \(scrollView.scrollPosition)) to \(newPosition) (by: \(String(describing: behavior)))")
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
      let command = String(firstToken.dropFirst(1))

      delegate?.messagesController(
        self, commandInvoked: command,
        arguments: tokens.dropFirst().map(String.init)
      )
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

    let isHeader = messageIsFirstInSection(id: message.id)
    messageSizingTemplate.configure(withMessage: message, isGroupHeader: isHeader, forMeasurements: true)
    signposter.emitEvent("View configuration complete", id: signpostID)

    // Because our message sizing template isn't actually inside of a table view
    // and is just floating around in empty space, we need to manually wrap the
    // message content label ourselves.
    //
    // XXX: This needs to be updated manually in the future if changes are made
    //      to the layout.
    messageSizingTemplate.messageContentLabel.preferredMaxLayoutWidth = tableView.frame.width - 50

    let height = messageSizingTemplate.fittingSize.height
    cachedMessageHeights[message.id] = height

    signposter.emitEvent("Measurement complete", id: signpostID)
    signposter.endInterval("Message Row Height Measurement", state)

    return height
  }
}
