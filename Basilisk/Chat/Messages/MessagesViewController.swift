import Cocoa
import Contempt
import FineJSON

private extension NSScrollView {
  var isScrolledToBottom: Bool {
    let clipView = contentView
    let documentView = documentView!
    let isScrolledToBottom = clipView.bounds.origin.y + clipView.bounds
      .height == documentView.frame.height
    return isScrolledToBottom
  }
}

class MessagesViewController: NSViewController {
  @IBOutlet var consoleScrollView: NSScrollView!
  @IBOutlet var consoleTextView: NSTextView!

  /// Called when the user tries to invoke a command.
  var onRunCommand: ((_ command: String, _ arguments: [String]) -> Void)?

  /// Called when the user tries to send a message.
  var onSendMessage: ((_ content: String) -> Void)?

  override func viewDidLoad() {
    super.viewDidLoad()
    consoleTextView.font = NSFont.monospacedSystemFont(
      ofSize: 10,
      weight: .regular
    )
  }

  func appendToConsole(line: String) {
    consoleTextView.string += line + "\n"

    if consoleScrollView.isScrolledToBottom {
      consoleTextView.scrollToEndOfDocument(self)
    }
  }

  @IBAction func inputTextFieldAction(_ sender: NSTextField) {
    let fieldText = sender.stringValue
    sender.stringValue = ""

    guard !fieldText.isEmpty else { return }

    if fieldText.starts(with: "/") {
      let tokens = fieldText.trimmingCharacters(in: .whitespacesAndNewlines)
        .split(separator: " ")
      let firstToken = tokens.first!
      let firstTokenWithoutSlash =
        firstToken[firstToken.index(after: firstToken.startIndex) ..< firstToken
          .endIndex]

      onRunCommand?(
        String(firstTokenWithoutSlash),
        tokens.dropFirst().map(String.init)
      )
    }

    onSendMessage?(fieldText)
  }
}
