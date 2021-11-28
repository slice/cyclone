import Cocoa
import Contempt

class MessageCollectionViewItem: NSCollectionViewItem {
  @IBOutlet var contentTextField: NSTextField!

  func configure(withMessage message: Message) {
    contentTextField.stringValue = message.content
  }
}
