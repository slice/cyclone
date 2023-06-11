import Cocoa

/// An image view with an overridden intrinsic content size.
///
/// This is used to ensure that forcibly fit message attachments into a smaller
/// area.
class IntrinsicImageView: NSImageView {
  /// The overridden intrinsic content size.
  var overriddenIntrinsicContentSize: NSSize?

  override var intrinsicContentSize: NSSize {
    overriddenIntrinsicContentSize ?? super.intrinsicContentSize
  }
}
