import Cocoa

extension NSScrollView {
  /// The amount the scroll view has scrolled.
  var scrollPosition: CGFloat {
    contentView.bounds.origin.y
  }

  /// A Boolean value that indicates whether the scroll view is currently
  /// scrolled to the bottom.
  var isScrolledToBottom: Bool {
    let bottomInset = additionalSafeAreaInsets.bottom
    return scrollPosition + contentView.bounds.height - bottomInset == documentView!.frame.height
  }

  /// The Y coordinate of the bottom of the scroll view, in the scroll view's
  /// coordinate space, accounting for a potential additional safe area inset.
  var bottomYCoordinate: Double {
    let bottomInset = additionalSafeAreaInsets.bottom
    return documentView!.bounds.height - contentView.bounds.height + bottomInset
  }

  /// Applies an inset to the content of the scroll view.
  ///
  /// This adds extra scrollable space to the top or bottom of the scroll view,
  /// but additionally offsets the scrollers to ensure that they span the bounds
  /// of the content.
  func applyInnerInsets(top: Double = 0, bottom: Double = 0) {
    additionalSafeAreaInsets = .init(top: top, left: 0, bottom: bottom, right: 0)
    scrollerInsets = .init(top: -top, left: 0, bottom: -bottom, right: 0)
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
    contentView.bounds.minY / (documentView!.frame.height - contentView.bounds.height)
  }
}
