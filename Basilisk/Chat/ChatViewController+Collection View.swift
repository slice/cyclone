import Cocoa
import Contempt

enum GuildsSection: CaseIterable {
  case main
}

extension NSUserInterfaceItemIdentifier {
  static let guild: Self = .init("guild")
}

extension ChatViewController {
  func makeCollectionViewLayout() -> NSCollectionViewFlowLayout {
    let layout = NSCollectionViewFlowLayout()
    layout.minimumInteritemSpacing = 0.0
    layout.sectionInset = NSEdgeInsets(
      top: 5.0,
      left: 5.0,
      bottom: 5.0,
      right: 5.0
    )
    layout.scrollDirection = .vertical
    return layout
  }

  func makeDiffableDataSource()
    -> NSCollectionViewDiffableDataSource<GuildsSection, Guild.ID>
  {
    NSCollectionViewDiffableDataSource(collectionView: guildsCollectionView) { [weak self] _, indexPath, identifier in
      guard let self = self else { return nil }
      let item = self.guildsCollectionView.makeItem(
        withIdentifier: .guild,
        for: indexPath
      ) as! GuildsCollectionViewItem
      let guild = (self.client!.guilds.first { $0.id == identifier })!
      guard let icon = guild.icon else {
        return item
      }
      let guildImage = NSImage(byReferencing: icon
        .url(withFileExtension: "png"))

      item.guildImageView.image = guildImage
      return item
    }
  }
}
