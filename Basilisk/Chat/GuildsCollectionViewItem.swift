import Cocoa

class GuildsCollectionViewItem: NSCollectionViewItem {
  private var boxView: NSBox!
  var guildImageView: NSImageView!

  override func loadView() {
    boxView = NSBox(frame: .zero)
    boxView.translatesAutoresizingMaskIntoConstraints = false
    boxView.boxType = .custom
    boxView.fillColor = .selectedContentBackgroundColor
    boxView.borderColor = .clear
    boxView.borderWidth = 0.0
    boxView.isTransparent = true
    boxView.cornerRadius = 5.0
    boxView.contentViewMargins = .zero

    guildImageView = NSImageView(frame: .zero)
    guildImageView.translatesAutoresizingMaskIntoConstraints = false

    boxView.addSubview(guildImageView)

    NSLayoutConstraint.activate([
      boxView.topAnchor.constraint(
        equalTo: guildImageView.topAnchor,
        constant: -3.0
      ),
      boxView.bottomAnchor.constraint(
        equalTo: guildImageView.bottomAnchor,
        constant: 3.0
      ),
      boxView.leadingAnchor.constraint(
        equalTo: guildImageView.leadingAnchor,
        constant: -3.0
      ),
      boxView.trailingAnchor.constraint(
        equalTo: guildImageView.trailingAnchor,
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
