import Cocoa

class RoundingView: NSView {
  @Invalidating(.display) var radius: CGFloat = 50.0

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("no")
  }

  override var wantsUpdateLayer: Bool { true }

  override func updateLayer() {
    layer!.masksToBounds = true
    layer!.cornerRadius = radius
  }

  override func draw(_ dirtyRect: NSRect) {
    for view in subviews {
      view.draw(dirtyRect)
    }
  }
}
