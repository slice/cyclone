import Cocoa

class GuildsCollectionViewItem: NSCollectionViewItem {
  private var boxView: NSBox!
  var guildImageView: NSImageView!

  override func loadView() {
    boxView = NSBox(frame: .zero)
    boxView.boxType = .custom
    boxView.fillColor = .selectedContentBackgroundColor
    boxView.translatesAutoresizingMaskIntoConstraints = false
    boxView.borderColor = .clear
    boxView.isTransparent = true
    boxView.cornerRadius = 5.0

    guildImageView = NSImageView(frame: .zero)
    guildImageView.translatesAutoresizingMaskIntoConstraints = false
    boxView.addSubview(guildImageView)

    NSLayoutConstraint.activate([
      boxView.topAnchor.constraint(equalTo: guildImageView.topAnchor),
      boxView.bottomAnchor.constraint(equalTo: guildImageView.bottomAnchor),
      boxView.leadingAnchor.constraint(equalTo: guildImageView.leadingAnchor),
      boxView.trailingAnchor.constraint(equalTo: guildImageView.trailingAnchor),
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
