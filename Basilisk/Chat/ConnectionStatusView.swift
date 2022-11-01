import Cocoa

enum ConnectionStatus {
  case connecting
  case connected
  case disconnected

  var color: NSColor {
    switch self {
    case .connecting: return .systemOrange
    case .connected: return .systemGreen
    case .disconnected: return .systemRed
    }
  }
}

final class ConnectionStatusView: NSView {
  var connectionStatus: ConnectionStatus = .disconnected {
    didSet {
      needsDisplay = true
      progressIndicator.isHidden = connectionStatus != .connecting
    }
  }

  private var progressIndicator: NSProgressIndicator!
  private static let inset: Double = 5.0

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setupView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupView()
  }

  private func setupView() {
    progressIndicator = NSProgressIndicator()
    progressIndicator.style = .spinning
    progressIndicator.translatesAutoresizingMaskIntoConstraints = false
    progressIndicator.isHidden = connectionStatus != .connecting
    progressIndicator.startAnimation(self)
    addSubview(progressIndicator)
    NSLayoutConstraint.activate([
      progressIndicator.topAnchor.constraint(equalTo: topAnchor, constant: -Self.inset),
      progressIndicator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: Self.inset),
      progressIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.inset),
      progressIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.inset),
      widthAnchor.constraint(equalTo: heightAnchor, multiplier: 1.0),
    ])
  }

  override func draw(_: NSRect) {
    if connectionStatus == .connecting {
      return
    }

    let path = NSBezierPath(ovalIn: bounds.insetBy(dx: Self.inset, dy: Self.inset))
    path.lineWidth = 1.0
    connectionStatus.color.shadow(withLevel: 0.2)!.setFill()
    connectionStatus.color.shadow(withLevel: 0.6)!.setStroke()
    path.fill()
    path.stroke()
  }
}
