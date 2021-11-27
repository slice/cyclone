import Cocoa

extension NSView {
  /// Returns a corresponding nib for this view.
  static var nib: NSNib? {
    NSNib(nibNamed: String(describing: self), bundle: Bundle(for: self))
  }
}

extension NSViewController {
  /// Returns a corresponding nib for this view controller.
  static var nib: NSNib? {
    NSNib(nibNamed: String(describing: self), bundle: Bundle(for: self))
  }
}
