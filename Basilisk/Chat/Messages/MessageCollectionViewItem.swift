import Cocoa
import Contempt

class MessageCollectionViewItem: NSTableCellView {
  @IBOutlet var contentTextField: NSTextField!

  func configure(withMessage message: Message) {
    contentTextField.stringValue = message.content
  }

  override func prepareForReuse() {
    contentTextField.stringValue = ""
  }
}
