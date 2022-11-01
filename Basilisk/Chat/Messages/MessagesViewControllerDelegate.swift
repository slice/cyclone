import Cocoa

@MainActor protocol MessagesViewControllerDelegate: AnyObject {
  /// Tells the delegate that a command was invoked.
  func messagesController(
    _ messagesController: MessagesViewController,
    commandInvoked: String, arguments: [String]
  )

  /// Tells the delegate that a message was sent.
  func messagesController(
    _ messagesController: MessagesViewController,
    messageSent: String
  )

  /// Tells the delegate that the message input field changed.
  func messagesControllerMessageInputFieldDidChange(_ messagesController: MessagesViewController, notification: Notification)

  /// Tells the delegate that the scroll view has neared the top of the
  /// available space.
  func messagesControllerDidScrollNearTop(_ messagesController: MessagesViewController)
}
