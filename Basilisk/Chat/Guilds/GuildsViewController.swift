import Cocoa
import Contempt

private enum GuildsSection: CaseIterable {
  case main
}

private extension NSUserInterfaceItemIdentifier {
  static let guild: Self = .init("guild")
}

class GuildsViewController: NSViewController {
  @IBOutlet var collectionView: NSCollectionView!
  private var dataSource: NSCollectionViewDiffableDataSource<
    GuildsSection,
    Guild.ID
  >!

  /// Called whenever the view controller needs to access a guild by ID.
  var getGuildWithID: ((Guild.ID) -> Guild?)!

  /// Called whenever a guild was selected.
  var onSelectedGuildWithID: ((Guild.ID) -> Void)?

  override func viewDidLoad() {
    collectionView.collectionViewLayout = makeCollectionViewLayout()
    dataSource = makeDiffableDataSource()
    collectionView.dataSource = dataSource
    collectionView.register(
      GuildsCollectionViewItem.self,
      forItemWithIdentifier: .guild
    )
    collectionView.delegate = self
  }

  public func applyGuilds(guilds: [Guild]) {
    var snapshot = NSDiffableDataSourceSnapshot<GuildsSection, Guild.ID>()
    snapshot.appendSections([.main])
    snapshot.appendItems(guilds.map(\.id), toSection: .main)
    dataSource.apply(snapshot)
  }

  private func makeCollectionViewLayout() -> NSCollectionViewFlowLayout {
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

  private func makeDiffableDataSource()
    -> NSCollectionViewDiffableDataSource<GuildsSection, Guild.ID>
  {
    NSCollectionViewDiffableDataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, identifier in
      guard let self = self else { return nil }
      let item = collectionView.makeItem(
        withIdentifier: .guild,
        for: indexPath
      ) as! GuildsCollectionViewItem

      guard let guild = self.getGuildWithID(identifier),
            let icon = guild.icon
      else {
        return item
      }
      let guildImage = NSImage(byReferencing: icon
        .url(withFileExtension: "png"))

      item.guildImageView.image = guildImage
      return item
    }
  }
}

extension GuildsViewController: NSCollectionViewDelegate {
  func collectionView(
    _: NSCollectionView,
    didSelectItemsAt indexPaths: Set<IndexPath>
  ) {
    guard let identifier = dataSource.itemIdentifier(for: indexPaths.first!)
    else { return }
    onSelectedGuildWithID?(identifier)
  }
}
