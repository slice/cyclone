import Cocoa
import Serpent

final class UnifiedMessageRow: NSTableCellView {
  @IBOutlet var roundingView: RoundingView!
  @IBOutlet var avatarImageView: NSImageView!
  @IBOutlet var authorLabel: NSTextField!
  @IBOutlet var contentStackView: NSStackView!
  @IBOutlet var messageContentLabel: NSTextField!
  @IBOutlet var timestampLabel: NSTextField!

  /// The wrapper view that makes up the majority of the content of a message
  /// row. In left to right locales, this is to the right of the avatar. This
  /// includes the author and timestamp labels above the message content, along
  /// with any accessories.
  @IBOutlet var messageHeaderContent: NSView!

  /// The stack view containing the author and timestamp labels.
  @IBOutlet var headerIdentityStack: NSStackView!

  @IBOutlet var spaceBetweenHeaderIdentityAndContent: NSLayoutConstraint!

  // Enforce a minimum height for group headers, so the avatar doesn't get
  // clipped.
  @IBOutlet var headerContentHeightConstraint: NSLayoutConstraint!

  // Vertical pinning for either the message content stack or the identity
  // stack. When not a group header, the identity stack is hidden.
  @IBOutlet var pinIdentityToTopOfHeader: NSLayoutConstraint!
  lazy var pinContentToTopOfHeader: NSLayoutConstraint = {
    let constraint = contentStackView.topAnchor.constraint(equalTo: messageHeaderContent.topAnchor)
    constraint.identifier = "PinContentToTop"
    return constraint
  }()

  // Vertical pinning for top-level cell content, so we can tweak spacing for
  // groups.
  @IBOutlet var pinHeaderToTopOfCell: NSLayoutConstraint!
  @IBOutlet var pinHeaderToBottomOfCell: NSLayoutConstraint!
  @IBOutlet var pinAvatarToTopOfCell: NSLayoutConstraint!

  // These are hardcoded for now. (dizzy)
  static let maximumImageWidth = 450.0
  static let maximumImageHeight = 300.0

  override func awakeFromNib() {
    super.awakeFromNib()
    authorLabel.font = .systemFont(ofSize: 13.0, weight: .semibold)
    timestampLabel.font = .systemFont(ofSize: 11.0)
    messageContentLabel.textColor = NSColor(name: nil) { appearance in
      switch appearance.bestMatch(from: [.aqua, .darkAqua]) {
      case .some(.darkAqua):
        return .labelColor.withAlphaComponent(0.65)
      default:
        return .labelColor
      }
    }
  }

  /// Configures a unified message row to display a message.
  func configure(withMessage message: Message, isGroupHeader: Bool, forMeasurements performingMeasurements: Bool = false) {
    authorLabel.stringValue = message.author.username
    roundingView.radius = 10
    if let avatar = message.author.avatar {
      avatarImageView.kf.setImage(with: avatar.url(withFileExtension: "png"))
    }

    timestampLabel.stringValue = message.id.timestamp.formatted(
      date: Calendar.current.isDate(message.id.timestamp, inSameDayAs: Date.now) ? .omitted : .numeric,
      time: .shortened
    )

    if message.content == "" {
      messageContentLabel.isHidden = true
    } else {
      messageContentLabel.stringValue = message.content
    }

    setupAppearance(isGroupHeader: isGroupHeader)
    setupAccessories(message: message, forMeasurements: performingMeasurements)
  }

  private func clampImageDimensions(width: Double, height: Double) -> (width: Double, height: Double) {
    let aspectRatio = width / height

    var newWidth = width
    var newHeight = height

    if newHeight > Self.maximumImageHeight {
      newHeight = Self.maximumImageHeight
      newWidth = newHeight * aspectRatio
    }
    if newWidth > Self.maximumImageWidth {
      newWidth = Self.maximumImageWidth
      newHeight = newWidth / aspectRatio
    }

    return (newWidth, newHeight)
  }

  func setupAccessories(message: Message, forMeasurements performingMeasurements: Bool = false) {
    for attachment in message.attachments {
      guard let width = attachment.width.map(Double.init), let height = attachment.height.map(Double.init) else {
        continue
      }

      let imageView = IntrinsicImageView()
      imageView.translatesAutoresizingMaskIntoConstraints = false
      imageView.imageScaling = .scaleAxesIndependently

      let aspectRatio = width / height
      let (clampedWidth, clampedHeight) = self.clampImageDimensions(width: width, height: height)

      imageView.overriddenIntrinsicContentSize = NSSize(width: clampedWidth, height: clampedHeight)
      imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

      let roundingView = RoundingView()
      roundingView.radius = 5.0
      roundingView.translatesAutoresizingMaskIntoConstraints = false
      roundingView.addSubview(imageView)
      roundingView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      roundingView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

      // The image wants to be at the clamped dimensions, but should shrink if
      // the user sizes the window down.
      let widthConstraint = imageView.widthAnchor.constraint(equalToConstant: clampedWidth)
      widthConstraint.priority = .defaultLow
      let heightConstraint = imageView.heightAnchor.constraint(equalToConstant: clampedHeight)
      heightConstraint.priority = .defaultLow

      NSLayoutConstraint.activate([
        imageView.topAnchor.constraint(equalTo: roundingView.topAnchor),
        imageView.bottomAnchor.constraint(equalTo: roundingView.bottomAnchor),
        imageView.trailingAnchor.constraint(equalTo: roundingView.trailingAnchor),
        imageView.leadingAnchor.constraint(equalTo: roundingView.leadingAnchor),
        imageView.widthAnchor.constraint(greaterThanOrEqualToConstant: 50.0),
        widthConstraint,
        heightConstraint,
        imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: aspectRatio)
      ])

      if !performingMeasurements {
        let loading = LoadingAttachmentView(frame: .zero)
        loading.translatesAutoresizingMaskIntoConstraints = false

        imageView.kf.setImage(with: attachment.proxyURL, placeholder: loading, progressBlock: { receivedSize, totalSize in
          if width > 100 { loading.switchToDeterminate(attachmentWidth: width) }
          loading.updateProgress(receivedSize: receivedSize, totalSize: totalSize)
        })
      }

      contentStackView.addView(roundingView, in: .bottom)
    }
  }

  func resetMessageAccessories() {
    contentStackView.setViews([], in: .bottom)
  }

  /// Configures this message row for a group header or normal appearance.
  private func setupAppearance(isGroupHeader: Bool) {
    avatarImageView.isHidden = !isGroupHeader
    headerIdentityStack.isHidden = !isGroupHeader

    // The next group of constraints conflict with each other, so deactivate
    // all of them first.
    spaceBetweenHeaderIdentityAndContent.isActive = false
    pinIdentityToTopOfHeader.isActive = false
    pinContentToTopOfHeader.isActive = false

    spaceBetweenHeaderIdentityAndContent.isActive = isGroupHeader
    pinIdentityToTopOfHeader.isActive = isGroupHeader
    pinContentToTopOfHeader.isActive = !isGroupHeader

    pinHeaderToTopOfCell.constant = isGroupHeader ? 10 : 2
    pinHeaderToBottomOfCell.constant = isGroupHeader ? 0 : 2
    pinAvatarToTopOfCell.constant = isGroupHeader ? 10 : 5

    headerContentHeightConstraint.isActive = isGroupHeader
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    messageContentLabel.isHidden = false
    resetMessageAccessories()
  }
}
