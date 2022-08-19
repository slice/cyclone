import Cocoa

final class APIURLTruncationAttachment: NSTextAttachment {
  init(text: String, font: NSFont = .systemFont(ofSize: 12.0, weight: .semibold), backgroundColor: NSColor) {
    super.init(data: nil, ofType: nil)
    attachmentCell = Cell(text: text, font: font, backgroundColor: backgroundColor)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  final class Cell: NSTextAttachmentCell {
    var padding: Double = 3.0
    private var text: NSString
    private var drawingFont: NSFont
    private var backgroundColor: NSColor
    private var foregroundColor: NSColor = .white

    private var attributes: [NSAttributedString.Key: Any] {
      [.font: drawingFont, .foregroundColor: foregroundColor]
    }

    init(text: String, font: NSFont, backgroundColor: NSColor) {
      self.text = NSString(string: text)
      self.drawingFont = font
      self.backgroundColor = backgroundColor
      super.init()
    }

    required init(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
      NSBezierPath(roundedRect: cellFrame, xRadius: 5.0, yRadius: 5.0).reversed.setClip()
      backgroundColor.setFill()
      cellFrame.fill()
      let textOrigin = cellFrame.origin.applying(.init(translationX: padding, y: 0))
      text.draw(at: textOrigin, withAttributes: attributes)
    }

    override func cellBaselineOffset() -> NSPoint {
      return .init(x: 0, y: drawingFont.descender)
    }

    override func cellSize() -> NSSize {
      let size = text.size(withAttributes: attributes)
      return .init(width: padding * 2 + size.width, height: size.height + 1.0)
    }
  }
}
