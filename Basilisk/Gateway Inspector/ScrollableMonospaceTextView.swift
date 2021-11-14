import SwiftUI

struct ScrollableMonospaceTextView: NSViewRepresentable {
  typealias NSViewType = NSScrollView

  /// The text contained within the text view.
  var text: String

  func makeNSView(context _: Context) -> NSScrollView {
    let textView = NSTextView()
    textView.font = .monospacedSystemFont(ofSize: 12.0, weight: .regular)
    textView.textContainerInset = NSSize(width: 10.0, height: 10.0)
    textView.isEditable = false
    textView.string = text
    textView.autoresizingMask = [.height, .width]
    let clipView = NSClipView()
    clipView.documentView = textView
    let scrollView = NSScrollView()
    scrollView.contentView = clipView
    return scrollView
  }

  func updateNSView(_ view: NSScrollView, context _: Context) {
    let textView = view.contentView.documentView as! NSTextView
    textView.string = text
  }
}
