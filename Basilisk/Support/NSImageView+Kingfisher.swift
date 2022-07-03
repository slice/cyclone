import Cocoa
import Kingfisher

extension NSImageView {
  func setImage(loadingFrom source: URL, destinationSize size: CGSize? = nil) {
    image = nil

    let computedSize: CGSize
    if let size = size {
      computedSize = size
    } else if bounds.size.width > 0 && bounds.size.height > 0 {
      computedSize = bounds.size
    } else if fittingSize.width > 0 && fittingSize.height > 0 {
      computedSize = fittingSize
    } else if intrinsicContentSize.width > 0 && intrinsicContentSize.height > 0 {
      computedSize = intrinsicContentSize
    } else {
      NSLog("[loading image view] couldn't find a proper downscale size for %@", String(describing: self))
      return
    }

    let loading = LoadingAttachmentView(frame: .zero)
    loading.shouldFillSuperview = computedSize.width < 60 && computedSize.height < 60
    loading.translatesAutoresizingMaskIntoConstraints = false

    let processor = DownsamplingImageProcessor(size: computedSize)

    kf.setImage(
      with: source,
      placeholder: loading,
      options: [.processor(processor), .cacheOriginalImage, .scaleFactor(NSScreen.main?.backingScaleFactor ?? 1.0)],
      progressBlock: { receivedSize, totalSize in
        if computedSize.width > 100 { loading.switchToDeterminate(attachmentWidth: computedSize.width) }
        loading.updateProgress(receivedSize: receivedSize, totalSize: totalSize)
      }
    ) { result in
      if case .failure(let error) = result, !error.isTaskCancelled && !error.isNotCurrentTask {
        NSLog("[loading image view] failed to load from %@: %@", source.absoluteString, String(describing: error))
      }
    }
  }
}
