import Cocoa
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import Kingfisher
import OrderedCollections
import os.log
import Serpent
import SwiftUI

extension NSUserInterfaceItemIdentifier {
  static let unifiedMessageRow: Self = .init("unified-message-row")
}

final class MessagesViewController: NSViewController {
  @IBOutlet var scrollView: NSScrollView!
  @IBOutlet var tableView: NSTableView!
  @IBOutlet var fieldAccessories: NSView!
  @IBOutlet var messageInputField: NSTextField!
  @IBOutlet var messageMenu: NSMenu!

  var fieldAccessoriesHostingView: NSHostingView<MessageFieldAccessoriesView>!
  var fieldAccessoriesHeight: NSLayoutConstraint!
  public var replyingToMessage: Message?

  lazy var quickSelectOutlineFloater: QuickSelectOutlineFloater = {
    let floater = QuickSelectOutlineFloater()
    floater.translatesAutoresizingMaskIntoConstraints = true
    floater.isHidden = true
    return floater
  }()

  var quickSelectedMessageID: Ref<Message>?
  var quickSelectSound: NSSound?

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
  public var oldestMessageID: Message.ID? { messages.elements.first?.value.id }

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

  let log = Logger(subsystem: "zone.slice.Cyclone", category: "messages-view-controller")
  lazy var signposter = OSSignposter(logger: log)

  override func viewDidLoad() {
    super.viewDidLoad()

    self.view.addSubview(quickSelectOutlineFloater)

    // Used to animate the message field's accessories view open or closed.
    fieldAccessoriesHeight = fieldAccessories.heightAnchor.constraint(equalToConstant: 1)
    fieldAccessoriesHeight.isActive = true

    fieldAccessoriesHostingView = NSHostingView(rootView: MessageFieldAccessoriesView())
    fieldAccessoriesHostingView.translatesAutoresizingMaskIntoConstraints = false
    fieldAccessories.addSubview(fieldAccessoriesHostingView)
    NSLayoutConstraint.activate([
      fieldAccessoriesHostingView.centerYAnchor.constraint(equalTo: fieldAccessories.centerYAnchor),
      fieldAccessoriesHostingView.leadingAnchor.constraint(equalTo: fieldAccessories.leadingAnchor, constant: 11),
      fieldAccessoriesHostingView.trailingAnchor.constraint(equalTo: fieldAccessories.trailingAnchor),
    ])

    setupDataSource()

    tableView.delegate = self
    tableView.register(UnifiedMessageRow.nib!, forIdentifier: .unifiedMessageRow)

    messageSizingTemplate =
      (tableView.makeView(withIdentifier: .unifiedMessageRow, owner: nil)! as! UnifiedMessageRow)

    // Inner insets seem to cause AppKit to behave strangely. Animating the
    // field accessories view open causes the scroll view to clip weirdly, and
    // it doesn't seem to scroll to the bottom all the way sometimes. We need to
    // figure out another way to apply some inner padding to the table view.
    //
    // scrollView.applyInnerInsets(bottom: 10)

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

    if BasiliskDefaults.bool(.loadSampleMessages) {
      applySampleData()
    }

    messageInputFieldTextChangedSink = NotificationCenter.default
      .publisher(for: NSControl.textDidChangeNotification, object: messageInputField)
      .sink { [unowned self] notification in
        self.delegate?.messagesControllerMessageInputFieldDidChange(self, notification: notification)
      }
  }

  /// Moves the quick select outline floater to outline a rectangle within the
  /// table view using an animation.
  func moveFloater(outliningRect rect: NSRect) {
    self.log.debug("moving floater to \(String(describing: rect))")
    quickSelectOutlineFloater.isHidden = false
    tableView.scrollToVisible(rect)
    NSAnimationContext.runAnimationGroup { context in
      context.duration = BasiliskDefaults[.quickSelectOutlineFloaterAnimationDuration]
      quickSelectOutlineFloater.animator().frame = tableView.convert(rect, to: self.view).insetBy(dx: -3, dy: -6)
    }
  }

  /// Moves the quick select outline floater to outline a row in the table view
  /// using an animation.
  func moveFloater(outliningRow: Int) {
    moveFloater(outliningRect: tableView.rect(ofRow: outliningRow))
  }

  @objc func quickSelectFinished(_: Any?) {
    guard let quickSelectedMessageID else { return }
    beginReplyingTo(message: messages[quickSelectedMessageID.id]!)
    quickSelectOutlineFloater.isHidden = true
    messageInputField.becomeFirstResponder()
    self.quickSelectedMessageID = nil
  }

  @objc override func cancelOperation(_: Any?) {
    if replyingToMessage != nil {
      finishReplying()
    }
  }

  func playQuickSelectSound() {
    guard BasiliskDefaults[.quickSelectPlaysSound] else { return }

    if quickSelectSound == nil, let clickURL = Bundle.main.url(forResource: "ClickMid", withExtension: "aif") {
      quickSelectSound = NSSound(contentsOf: clickURL, byReference: true)
      quickSelectSound?.volume = Float(BasiliskDefaults[.quickSelectSoundVolume])
    }

    guard let sound = quickSelectSound else { return }

    if sound.isPlaying { sound.stop() }
    sound.play()
  }

  @objc func quickSelectOlder(_: Any?) {
    let olderIndex = quickSelectedMessageID == nil
      ? messages.count - 1
      : messages.keys.firstIndex(of: quickSelectedMessageID!.id)! - 1
    guard olderIndex > -1 else { return }
    moveFloater(outliningRow: olderIndex)
    quickSelectedMessageID = messages.elements[olderIndex].value.ref
    playQuickSelectSound()
  }

  @objc func quickSelectNewer(_: Any?) {
    guard let quickSelectedMessageID else { return }
    let newerIndex = messages.keys.firstIndex(of: quickSelectedMessageID.id)! + 1
    guard newerIndex <= messages.count - 1 else { return }
    moveFloater(outliningRow: newerIndex)
    self.quickSelectedMessageID = messages.elements[newerIndex].value.ref
    playQuickSelectSound()
  }

  @IBAction func messageMenuReply(_: NSMenuItem) {
    guard tableView.clickedRow != -1 else { return }
    let message = messages.elements[tableView.clickedRow].value
    beginReplyingTo(message: message)
  }

  /// Begins replying to a message.
  ///
  /// The message field's accessories view is animated open if necessary.
  func beginReplyingTo(message: Message) {
    replyingToMessage = message
    fieldAccessoriesHostingView.rootView = MessageFieldAccessoriesView(replyingToMessage: message)

    if messageFieldAccessoriesHidden {
      showMessageFieldAccessories()
    }
  }

  /// Stops replying to a message.
  ///
  /// This does not send a message; it merely updates internal state and hides
  /// the message field's accessories view if necessary.
  func finishReplying() {
    replyingToMessage = nil

    if !messageFieldAccessoriesHidden {
      hideMessageFieldAccessories()
    }
  }

  /// A Boolean value that indicates whether the message field's accessories
  /// view is currently hidden.
  var messageFieldAccessoriesHidden: Bool {
    fieldAccessories.isHidden
  }

  /// Animates the message field's accessories view open.
  func showMessageFieldAccessories() {
    fieldAccessories.isHidden = false
    view.window!.layoutIfNeeded()
    NSAnimationContext.runAnimationGroup { context in
      context.allowsImplicitAnimation = true
      context.duration = BasiliskDefaults[.messageFieldAccessoriesAnimationDuration]
      fieldAccessoriesHeight.constant = 30
      view.window!.layoutIfNeeded()
    }
  }

  /// Animates the message field's accessories view closed.
  func hideMessageFieldAccessories() {
    fieldAccessoriesHeight.constant = 1
    NSAnimationContext.runAnimationGroup { context in
      context.allowsImplicitAnimation = true
      context.duration = BasiliskDefaults[.messageFieldAccessoriesAnimationDuration]
      view.window!.layoutIfNeeded()
    } completionHandler: { [unowned self] in
      fieldAccessories.isHidden = true
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

      let newPosition: Double = switch behavior {
      case .addingHeightDifference:
        // Scroll to where we were before, but also accounting for the new
        // messages at the top.
        savedScrollPosition + (newHeight - savedContentHeight)
      case .usingSavedPosition:
        // Scroll to where we were before.
        savedScrollPosition
      case .toBottom:
        // Scroll to the bottom of the scroll view.
        scrollView.bottomYCoordinate
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

extension MessagesViewController: NSMenuItemValidation {
  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    if menuItem.action == #selector(messageMenuReply), tableView.clickedRow == -1 {
      return false
    }
    return true
  }
}
