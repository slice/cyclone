import Cocoa

class MessageGroupHeader: NSView, NSCollectionViewElement {
  @IBOutlet var groupAvatarImageView: NSImageView!
  @IBOutlet var groupAvatarRounding: RoundingView!
  @IBOutlet var groupAuthorTextField: NSTextField!
  @IBOutlet var groupTimestampTextField: NSTextField!

  var avatarLoadingTask: Task<Void, Error>?

  override func prepareForReuse() {
    super.prepareForReuse()
    if let task = avatarLoadingTask {
      task.cancel()
    }
    groupAvatarImageView.image = nil
    groupAuthorTextField.stringValue = ""
    groupTimestampTextField.stringValue = ""
  }
}
