import Cocoa

class RoundingView: NSView {
  @Invalidating(.display) var radius: CGFloat = 50.0

  override var wantsUpdateLayer: Bool { true }

  override func updateLayer() {
    layer!.masksToBounds = true
    layer!.cornerRadius = radius
    layer!.cornerCurve = .continuous
  }
}
