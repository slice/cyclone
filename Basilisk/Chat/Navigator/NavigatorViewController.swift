import Cocoa
import Contempt

private extension NSUserInterfaceItemIdentifier {
  static let navigatorSection: Self = .init("navigator-section")
  static let navigatorGuild: Self = .init("navigator-guild")
}

class NavigatorViewController: NSViewController {
  @IBOutlet var outlineView: NSOutlineView!

  weak var delegate: NavigatorViewControllerDelegate?

  private var guildIDs: [Guild.ID] = []

  override func viewDidLoad() {
    outlineView.dataSource = self
    outlineView.delegate = self
  }

  func reloadWithGuildIDs(_ ids: [Guild.ID]) {
    guildIDs = ids
    outlineView.reloadData()
  }

  private func guild(withID id: Guild.ID) -> Guild {
    guard let guild = delegate?.navigatorViewController(
      self,
      requestingGuildWithID: id
    ) else {
      preconditionFailure("navigator was unable to request guild with id \(id)")
    }

    return guild
  }
}

class NavigatorOutlineItem: NSObject {
  public enum Kind: Hashable {
    case section
    case guild
  }

  public let kind: Kind
  public let id: String

  public init(kind: Kind, id: String) {
    self.kind = kind
    self.id = id
  }

  override func isEqual(_ object: Any?) -> Bool {
    if case let item as NavigatorOutlineItem = object,
       item.id == id, item.kind == kind
    {
      return true
    }

    return false
  }
}

private let rootNavigatorItems: [NavigatorOutlineItem] = [
  NavigatorOutlineItem(kind: .section, id: "pinned"),
  NavigatorOutlineItem(kind: .section, id: "dms"),
  NavigatorOutlineItem(kind: .section, id: "guilds"),
]

// MARK: Channel Sorting

// Discord channel sorting is complicated. To do it, assume that each channel is
// within a category. (Any channel that isn't within a category can be assumed
// to be in a special category that is always ordered first.)
//
// Then, sort the categories according to their position, falling back to the
// ID. Then, within each category, sort the channels according to their type
// (text comes before voice), then position, then ID.
//
// Assume positions to only be unique within each (category, type).
//
// For example:
//
// [Text: 0]
// [Text: 1]
// [Voice: 0]
// [Category: 0]
//   [Text: 0]
//   [Text: 5]
//   [Text: 7]
// [Category: 1]
//   [Text: 1]
//   [Text: 2]
//   [Voice: 0]
// [Category: 3]
//   [Text: 4]
//   [Text: 9]
//   [Voice: 1]
//   [Voice: 3]
//
// Kudos to Danny#0007 and some friends in Dannyware for their assistance.

private extension Array where Element == Channel {
  /// Sorts an array of channels according to their type, then position, then
  /// ID.
  func sortedByTypeAndPosition() -> [Channel] {
    sorted {
      ($0.type.rawValue, $0.position, $0.id) <
        ($1.type.rawValue, $1.position, $1.id)
    }
  }
}

private extension Guild {
  var sortedTopLevelChannels: [Channel] {
    // You can't nest categories (yet!)
    channels.filter { $0.type == .category || $0.parentID == nil }
      .sortedByTypeAndPosition()
  }
}

extension NavigatorViewController: NSOutlineViewDataSource {
  func outlineView(_: NSOutlineView, child index: Int,
                   ofItem item: Any?) -> Any
  {
    if item == nil {
      // root items are direct messages, pins, and guilds
      return rootNavigatorItems[index]
    }

    switch item {
    case let item as NavigatorOutlineItem:
      switch item.kind {
      case .section:
        switch item.id {
        case "pinned": return NSNull()
        case "dms": return NSNull()
        case "guilds":
          let guildID = guildIDs[index]
          return NavigatorOutlineItem(kind: .guild, id: String(guildID.uint64))
        default: return NSNull()
        }
      case .guild:
        let guild = guild(withID: Snowflake(string: item.id))
        let sortedTopLevelChannels = guild.sortedTopLevelChannels
        return ChannelRef(guild: guild, channel: sortedTopLevelChannels[index])
      }
    case let channel as ChannelRef:
      guard channel.type == .category else {
        NSLog(
          "[warning] navigator tried to request children of a non-category channel"
        )
        return NSNull()
      }

      let guild = guild(withID: Snowflake(uint64: channel.guildID))
      let channels = guild.channels.filter { $0.parentID?.uint64 == channel.id }
        .sortedByTypeAndPosition()
      return ChannelRef(guild: guild, channel: channels[index])
    default: return NSNull()
    }
  }

  func outlineView(_: NSOutlineView, isGroupItem item: Any) -> Bool {
    if case let item as NavigatorOutlineItem = item {
      return item.kind == .section
    }

    return false
  }

  func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
    switch item {
    case is NavigatorOutlineItem:
      return true
    case let channel as ChannelRef:
      return channel.type == .category
    default: return false
    }
  }

  func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    if item == nil {
      return rootNavigatorItems.count
    }

    switch item {
    case let item as NavigatorOutlineItem:
      switch item.kind {
      case .section:
        switch item.id {
        case "pinned": return 0
        case "dms": return 0
        case "guilds": return guildIDs.count
        default: preconditionFailure()
        }
      case .guild:
        let guild = guild(withID: Snowflake(string: item.id))
        return guild.sortedTopLevelChannels.count
      }
    case let channel as ChannelRef:
      guard channel.type == .category else {
        return 0
      }
      let guild = guild(withID: Snowflake(uint64: channel.guildID))
      return guild.channels.filter { $0.parentID?.uint64 == channel.id }.count
    default: return 0
    }
  }
}

private extension ChannelType {
  var systemSymbolName: String {
    switch self {
    case .category:
      return "folder.fill"
    case .dm:
      return "person.crop.circle.fill"
    case .groupDM:
      return "person.2.circle.fill"
    case .voice:
      return "speaker.wave.2.fill"
    default:
      return "number"
    }
  }
}

extension NavigatorViewController: NSOutlineViewDelegate {
  func outlineView(
    _ outlineView: NSOutlineView,
    viewFor _: NSTableColumn?,
    item: Any
  ) -> NSView? {
    switch item {
    case let item as NavigatorOutlineItem:
      switch item.kind {
      case .section:
        let view = outlineView.makeView(
          withIdentifier: .navigatorSection,
          owner: nil
        ) as! NSTableCellView
        let name: String
        switch item.id {
        case "pinned":
          name = "Pinned"
        case "dms":
          name = "Direct Messages"
        case "guilds":
          name = "Servers"
        default:
          preconditionFailure()
        }
        view.textField?.stringValue = name
        return view
      case .guild:
        let view = outlineView.makeView(
          withIdentifier: .navigatorGuild,
          owner: nil
        ) as! NavigatorGuildCellView

        let snowflake = Snowflake(string: item.id)
        let guild = guild(withID: snowflake)
        view.textField?.stringValue = guild.name

        view.roundingView.radius = 6.0

        Task {
          guard let url = guild.icon?.url(withFileExtension: "png") else {
            return
          }

          let guildImage = try await ImageCache.shared.image(at: url)
          view.imageView?.image = guildImage
        }

        return view
      }
    case let channel as ChannelRef:
      // TODO: don't use .navigatorGuild
      let view = outlineView.makeView(
        withIdentifier: .navigatorGuild,
        owner: nil
      ) as! NavigatorGuildCellView
      view.roundingView.radius = 0.0
      let guild = guild(withID: Snowflake(uint64: channel.guildID))

      let channelID = Snowflake(uint64: channel.id)
      let channel = guild.channels.first(where: { $0.id == channelID })!

      view.imageView?.image = NSImage(
        systemSymbolName: channel.type.systemSymbolName,
        accessibilityDescription: nil
      )
      view.textField?.stringValue = channel.name

      return view
    default:
      return nil
    }
  }

  func outlineView(_: NSOutlineView, shouldSelectItem item: Any) -> Bool {
    if let channel = item as? ChannelRef, channel.type == .text {
      return true
    }

    return false
  }

  func outlineViewSelectionDidChange(_: Notification) {
    let channel = outlineView
      .item(atRow: outlineView.selectedRow) as! ChannelRef
    delegate?.navigatorViewController(
      self,
      didSelectChannelWithID: Snowflake(uint64: channel.id),
      inGuildWithID: Snowflake(uint64: channel.guildID)
    )
  }

  func outlineView(_: NSOutlineView,
                   tintConfigurationForItem _: Any) -> NSTintConfiguration?
  {
    return .monochrome
  }
}
