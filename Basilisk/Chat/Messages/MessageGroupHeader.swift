import Cocoa

class MessageGroupHeader: NSView, NSCollectionViewElement {
  @IBOutlet var groupAvatarImageView: NSImageView!
  @IBOutlet var groupAvatarRounding: RoundingView!
  @IBOutlet var groupAuthorTextField: NSTextField!

  override func prepareForReuse() {
    groupAvatarImageView.image = nil
    groupAuthorTextField.stringValue = ""
  }
}
