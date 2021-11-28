import Cocoa
import Contempt

extension MessagesViewController: NSCollectionViewDelegateFlowLayout {
  private func fullWidthOfCollectionView(_ collectionView: NSCollectionView) -> Double {
    return collectionView.bounds.width - (horizontalMessageSectionInset * 2.0)
  }

  func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
    let dataSource = collectionView.dataSource! as! MessagesDiffableDataSource
    let messageID = dataSource.itemIdentifier(for: indexPath)!

    // TODO(skip): replace this with an O(1) operation.
    guard let message = messages.first(where: { $0.id == messageID }) else {
      preconditionFailure("while measuring message heights: failed to find message with ID \(messageID.uint64)")
    }

    let fullWidth = fullWidthOfCollectionView(collectionView)

    if let cachedMessageSize = cachedMessageSizes[message.id] {
      // we must be at least 100.0 points away from the message content if we
      // want to use the cached value. if we are nearing the boundary of the
      // collection view, recalculate the size as the message content is likely
      // to wrap at this point, thus necessitating a recalculation if we want
      // the message bounds to hug the content.
      if fullWidth - cachedMessageSize.width > 100.0 {
        return NSSize(width: fullWidth, height: cachedMessageSize.height)
      }
    }

    let signpostID = signposter.makeSignpostID()
    let name: StaticString = "Message Height Measurement"
    let signpostState = signposter.beginInterval(name, id: signpostID)

    messageSizingTemplate.configure(withMessage: message)
    messageSizingTemplate.contentTextField.preferredMaxLayoutWidth = fullWidth
    let size = messageSizingTemplate.view.fittingSize

    signposter.endInterval(name, signpostState)

    cachedMessageSizes[message.id] = size
    return NSSize(width: fullWidth, height: size.height)
  }

  func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> NSSize {
    return NSSize(width: fullWidthOfCollectionView(collectionView), height: 30.0)
  }

  func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, insetForSectionAt section: Int) -> NSEdgeInsets {
    let collectionViewLayout = collectionViewLayout as! NSCollectionViewFlowLayout
    let spacingBetweenMessages = collectionViewLayout.minimumLineSpacing

    let verticalInset = 15.0
    return NSEdgeInsets(top: spacingBetweenMessages,
                        left: horizontalMessageSectionInset,
                        bottom: verticalInset,
                        right: horizontalMessageSectionInset)
  }
}
