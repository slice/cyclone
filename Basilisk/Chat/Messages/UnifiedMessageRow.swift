import Cocoa
import Serpent
import Kingfisher
import os.log

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

  /// Indicates whether this message row is currently set up as a group header.
  var isGroupHeader: Bool = true

  static let log = Logger(subsystem: "zone.slice.Basilisk", category: "unified-message-row")

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
      avatarImageView.setImage(loadingFrom: avatar.url(withFileExtension: "png"))
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
    guard !UserDefaults.standard.bool(forKey: "BSLKIgnoreMessageAccessories") else {
      return
    }

    for attachment in message.attachments where attachment.contentType?.isSubtype(of: .image) ?? false {
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
      // When performing measurements, use a required content compression
      // resistance priority. If we use `defaultLow`, then the template view
      // will shrink itself to a size that is nowhere near representative
      // of the message's true height in the table view, resulting in janky
      // scrolling due to the height mismatches.
      imageView.setContentCompressionResistancePriority(performingMeasurements ? .required : .defaultLow, for: .vertical)

      let roundingView = RoundingView()
      roundingView.radius = 5.0
      roundingView.translatesAutoresizingMaskIntoConstraints = false
      roundingView.addSubview(imageView)
      roundingView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      // Ditto.
      roundingView.setContentCompressionResistancePriority(performingMeasurements ? .required : .defaultLow, for: .vertical)

      NSLayoutConstraint.activate([
        imageView.topAnchor.constraint(equalTo: roundingView.topAnchor),
        imageView.bottomAnchor.constraint(equalTo: roundingView.bottomAnchor),
        imageView.trailingAnchor.constraint(equalTo: roundingView.trailingAnchor),
        imageView.leadingAnchor.constraint(equalTo: roundingView.leadingAnchor),
        imageView.widthAnchor.constraint(greaterThanOrEqualToConstant: 50.0),
        imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: aspectRatio)
      ])

      if !performingMeasurements {
        imageView.setImage(loadingFrom: attachment.proxyURL)
      }

      contentStackView.addArrangedSubview(roundingView)

      if UserDefaults.standard.bool(forKey: "BSLKMessageRowHeightDebugging") {
        Self.log.debug("*** Set up an attachment for \(message.id.string, privacy: .public) (\"\(message.content, privacy: .public)\")")
        Self.log.debug("    accessory height: \(roundingView.fittingSize.height, privacy: .public), (incorrect) fitting size for this view: \(self.fittingSize.height, privacy: .public)")
        Self.log.debug("    is group header? \(self.isGroupHeader, privacy: .public)")

        func printFittingSize(_ view: NSView, label: String) {
          Self.log.debug("    \(label, privacy: .public)'s fitting height: \(view.fittingSize.height, privacy: .public)")
        }

        printFittingSize(self, label: "myself")
        printFittingSize(contentStackView, label: "content stack view")
        printFittingSize(headerIdentityStack, label: "identity stack view")
        printFittingSize(messageHeaderContent, label: "header content")
      }
    }
  }

  func resetMessageAccessories() {
    for arrangedSubview in contentStackView.arrangedSubviews where arrangedSubview != self.messageContentLabel {
      contentStackView.removeArrangedSubview(arrangedSubview)
      arrangedSubview.removeFromSuperview()
    }
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
    self.isGroupHeader = isGroupHeader
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    messageContentLabel.isHidden = false
    avatarImageView.image = nil
    avatarImageView.kf.cancelDownloadTask()
    resetMessageAccessories()
    isGroupHeader = true
  }
}
