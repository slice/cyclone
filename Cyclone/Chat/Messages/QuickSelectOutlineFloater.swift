import Cocoa

final class QuickSelectOutlineFloater: NSView {
  override func draw(_: NSRect) {
    let bezierPath = NSBezierPath(roundedRect: self.bounds.insetBy(dx: 6, dy: 6), xRadius: 5, yRadius: 5)
    bezierPath.lineWidth = 6
    NSColor.black.setStroke()
    bezierPath.stroke()
    bezierPath.lineWidth = 3
    NSColor.white.setStroke()
    bezierPath.stroke()
  }
}
