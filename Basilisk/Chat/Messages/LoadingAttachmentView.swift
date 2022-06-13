import Cocoa
import Kingfisher

final class LoadingAttachmentView: NSView, Placeholder {
  private lazy var progressIndicator: NSProgressIndicator = {
    let view = NSProgressIndicator()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.style = .spinning
    view.startAnimation(self)
    return view
  }()

  private var hasSwitchedToDeterminate: Bool = false

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setupView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupView()
  }

  private func setupView() {
    addSubview(progressIndicator)

    NSLayoutConstraint.activate([
      progressIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
      progressIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
    ])
  }

  /// Switch the view to a determinate style.
  func switchToDeterminate(attachmentWidth width: Double) {
    guard !hasSwitchedToDeterminate else { return }
    hasSwitchedToDeterminate = true

    progressIndicator.isIndeterminate = false
    progressIndicator.style = .bar

    let horizontalInset = 20.0
    let maximumWidth = 150.0
    let width = width <= horizontalInset ? width : min(width - horizontalInset, maximumWidth)
    progressIndicator.widthAnchor.constraint(equalToConstant: width).isActive = true
  }

  /// Update the progress of the view.
  ///
  /// This only has a visible effect if the view has switched to a determinate
  /// style.
  func updateProgress(receivedSize: Int64, totalSize: Int64) {
    progressIndicator.maxValue = Double(totalSize)
    progressIndicator.doubleValue = Double(receivedSize)
  }
}
