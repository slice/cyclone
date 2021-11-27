import Cocoa

/// A `NSCollectionViewFlowLayout` subclass that always invalidates its
/// delegate's metrics on a bounds change.
///
/// This lets the collection view layout with a surrounding window, which does
/// not happen by default.
class InvalidatingCollectionViewFlowLayout: NSCollectionViewFlowLayout {
  override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool {
    true
  }

  override func invalidationContext(forBoundsChange newBounds: NSRect) -> NSCollectionViewLayoutInvalidationContext {
    let context = super.invalidationContext(forBoundsChange: newBounds) as! NSCollectionViewFlowLayoutInvalidationContext
    context.invalidateFlowLayoutDelegateMetrics = true
    return context
  }
}
