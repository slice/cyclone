import Cocoa

class GuildsCollectionViewItem: NSCollectionViewItem {
  private var boxView: NSBox!
  private var roundingView: RoundingView!
  var guildImageView: NSImageView!

  override func loadView() {
    let cornerRadius = 10.0

    boxView = NSBox(frame: .zero)
    boxView.translatesAutoresizingMaskIntoConstraints = false
    boxView.boxType = .custom
    boxView.fillColor = .selectedContentBackgroundColor
    boxView.borderColor = .clear
    boxView.borderWidth = 0.0
    boxView.isTransparent = true
    boxView.cornerRadius = cornerRadius
    boxView.contentViewMargins = .zero

    roundingView = RoundingView(frame: .zero)
    roundingView.translatesAutoresizingMaskIntoConstraints = false
    roundingView.radius = cornerRadius

    guildImageView = NSImageView(frame: .zero)
    guildImageView.translatesAutoresizingMaskIntoConstraints = false

    roundingView.addSubview(guildImageView)
    boxView.addSubview(roundingView)

    NSLayoutConstraint.activate([
      guildImageView.topAnchor.constraint(equalTo: roundingView.topAnchor),
      guildImageView.bottomAnchor
        .constraint(equalTo: roundingView.bottomAnchor),
      guildImageView.leadingAnchor
        .constraint(equalTo: roundingView.leadingAnchor),
      guildImageView.trailingAnchor
        .constraint(equalTo: roundingView.trailingAnchor),
      boxView.topAnchor.constraint(
        equalTo: roundingView.topAnchor,
        constant: -3.0
      ),
      boxView.bottomAnchor.constraint(
        equalTo: roundingView.bottomAnchor,
        constant: 3.0
      ),
      boxView.leadingAnchor.constraint(
        equalTo: roundingView.leadingAnchor,
        constant: -3.0
      ),
      boxView.trailingAnchor.constraint(
        equalTo: roundingView.trailingAnchor,
        constant: 3.0
      ),
    ])

    view = boxView
  }

  override var isSelected: Bool {
    didSet {
      boxView.isTransparent = !isSelected
    }
  }

  override func prepareForReuse() {
    boxView.isTransparent = true
    guildImageView.image = nil
  }
}
