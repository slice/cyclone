import Cocoa
import Serpent
import Kingfisher

class IntrinsicImageView: NSImageView {
  var overriddenIntrinsicContentSize: NSSize?

  override var intrinsicContentSize: NSSize {
    overriddenIntrinsicContentSize ?? super.intrinsicContentSize
  }
}

class MessageRow: NSView {
  @IBOutlet var contentTextField: NSTextField!
  @IBOutlet var partsStackView: NSStackView!

  static let maxWidth = 450.0
  static let maxHeight = 300.0

  func configure(withMessage message: Message, forMeasurements measurements: Bool = false) {
    contentTextField.stringValue = message.content

    for attachment in message.attachments {
      guard let widthInt = attachment.width,
            let heightInt = attachment.height else {
        continue
      }

      let imageView = IntrinsicImageView()
      imageView.translatesAutoresizingMaskIntoConstraints = false
      imageView.imageScaling = .scaleAxesIndependently

      var width = Double(widthInt)
      var height = Double(heightInt)
      let aspectRatio = width / height

      if height > Self.maxHeight {
        height = Self.maxHeight
        width = height * aspectRatio
      }

      if width > Self.maxWidth {
        width = Self.maxWidth
        height = width / aspectRatio
      }

      imageView.overriddenIntrinsicContentSize = NSSize(width: width, height: height)
      imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

      let roundingView = RoundingView()
      roundingView.radius = 5.0
      roundingView.translatesAutoresizingMaskIntoConstraints = false
      roundingView.subviews = [imageView]
      roundingView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      roundingView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

      let widthConstraint = imageView.widthAnchor.constraint(equalToConstant: width)
      widthConstraint.priority = .defaultLow
      let heightConstraint = imageView.heightAnchor.constraint(equalToConstant: height)
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

      if !measurements {
        let loading = LoadingAttachmentView(frame: .zero)
        loading.translatesAutoresizingMaskIntoConstraints = false

        imageView.kf.setImage(with: attachment.proxyURL, placeholder: loading, progressBlock: { receivedSize, totalSize in
          if width > 100 {
            loading.switchToDeterminate(attachmentWidth: width)
          }

          loading.updateProgress(receivedSize: receivedSize, totalSize: totalSize)
        })
      }

      partsStackView.addView(roundingView, in: .bottom)
    }
  }

  private func resetMessageAttachments() {
    partsStackView.setViews([], in: .bottom)
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    contentTextField.stringValue = ""
    resetMessageAttachments()
  }
}
