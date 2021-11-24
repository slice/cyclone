import Cocoa

class MessageGroupHeader: NSView, NSCollectionViewElement {
  @IBOutlet var groupAvatarImageView: NSImageView!
  @IBOutlet var groupAvatarRounding: RoundingView!
  @IBOutlet var groupAuthorTextField: NSTextField!
  @IBOutlet var groupTimestampTextField: NSTextField!

  override func prepareForReuse() {
    super.prepareForReuse()
    groupAvatarImageView.image = nil
    groupAuthorTextField.stringValue = ""
    groupTimestampTextField.stringValue = ""
  }
}
