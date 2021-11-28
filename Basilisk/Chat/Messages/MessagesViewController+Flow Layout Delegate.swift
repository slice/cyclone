import Cocoa
import Contempt

extension MessagesViewController: NSCollectionViewDelegateFlowLayout {
  private func fullWidthOfCollectionView(_ collectionView: NSCollectionView) -> Double {
    let insets = collectionView.collectionViewLayout as! NSCollectionViewFlowLayout
    return collectionView.bounds.width - (insets.sectionInset.left + insets.sectionInset.right)
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
    let size = messageSizingTemplate.view.fittingSize
    signposter.endInterval(name, signpostState)

    cachedMessageSizes[message.id] = size
    return NSSize(width: fullWidth, height: size.height)
  }

  func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> NSSize {
    let baseHeight = 30.0
    let spaceFromHeaderToFirstMessage = 5.0
    let extraSpacing = 10.0
    return NSSize(width: fullWidthOfCollectionView(collectionView),
                  height: baseHeight + extraSpacing + spaceFromHeaderToFirstMessage)
  }
}
