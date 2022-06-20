import Cocoa

extension NSScrollView {
  /// The amount the scroll view has scrolled.
  var scrollPosition: CGFloat {
    return contentView.bounds.origin.y
  }

  /// A Boolean value that indicates whether the scroll view is currently
  /// scrolled to the bottom.
  var isScrolledToBottom: Bool {
    return scrollPosition + contentView.bounds.height == documentView!.frame.height
  }

  /// Scrolls to the bottom of the scroll view.
  func scrollToEnd() {
    let totalHeight = documentView!.frame.height
    let clipViewHeight = contentView.bounds.height
    contentView.scroll(to: NSPoint(x: 0.0, y: totalHeight - clipViewHeight))
    reflectScrolledClipView(contentView)
  }

  /// The percentage the user has scrolled.
  var scrollPercentage: Double {
    return contentView.bounds.minY / (documentView!.frame.height - contentView.bounds.height)
  }
}
