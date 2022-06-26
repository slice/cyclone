import Cocoa
import Serpent

private extension NSUserInterfaceItemIdentifier {
  static let navigatorSection: Self = .init("navigator-section")
  static let navigatorGuild: Self = .init("navigator-guild")
}

final class NavigatorViewController: NSViewController {
  @IBOutlet var outlineView: NSOutlineView!

  weak var delegate: NavigatorViewControllerDelegate?

  private var guildIDs: [Guild.ID] = []
  private var privateChannelIDs: [PrivateChannel.ID] = []

  override func viewDidLoad() {
    outlineView.dataSource = self
    outlineView.delegate = self
  }

  func reload(guildIDs ids: [Guild.ID]) {
    if guildIDs.isEmpty && !ids.isEmpty {
      // If we are receiving our first guilds, automatically expand the guild
      // list so the user can immediately see them.
      let guildsItem = NavigatorOutlineItem.rootItems.first { $0.id == "guilds" }
      outlineView.expandItem(guildsItem)
    }

    guildIDs = ids
    outlineView.reloadData()
  }

  func reload(privateChannelIDs ids: [PrivateChannel.ID]) {
    privateChannelIDs = ids
    outlineView.reloadData()
  }
}

extension NavigatorViewController {
  private func guild(withID id: Guild.ID) -> Guild {
    guard let guild = delegate?.navigatorViewController(self, requestingGuildWithID: id) else {
      preconditionFailure("navigator couldn't request guild with id \(id)")
    }
    return guild
  }

  private func privateChannel(withID id: PrivateChannel.ID) -> PrivateChannel {
    guard let pc = delegate?.navigatorViewController(self, requestingPrivateChannelWithID: id) else {
      preconditionFailure("navigator couldn't request private channel with id: \(id)")
    }
    return pc
  }
}

extension NavigatorViewController: NSOutlineViewDataSource {
  func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any
  {
    let userID = delegate?.navigatorViewController(self, didRequestCurrentUserID: ())

    if item == nil {
      // root items are direct messages, pins, and guilds
      return NavigatorOutlineItem.rootItems[index]
    }

    switch item {
    case let item as NavigatorOutlineItem:
      switch item.kind {
      case .section:
        switch item.id {
        case "pinned": return NSNull()
        case "dms":
          return ChannelRef(privateChannel: privateChannel(withID: privateChannelIDs[index]))
        case "guilds":
          return NavigatorOutlineItem(kind: .guild, id: guildIDs[index].string)
        default: return NSNull()
        }
      case .guild:
        let guild = guild(withID: Snowflake(string: item.id))
        let sortedTopLevelChannels = guild.sortedTopLevelChannels(forUserWith: userID)
        return ChannelRef(guild: guild, channel: sortedTopLevelChannels[index])
      }
    case let channelRef as ChannelRef:
      guard channelRef.type == .category else {
        NSLog("[warning] navigator tried to request children of a non-category channel")
        return NSNull()
      }

      guard let guildID = channelRef.guildID else {
        NSLog("[warning] category channel ref had no associated guild id")
        return NSNull()
      }

      let guild = guild(withID: Snowflake(uint64: guildID))
      let channels = guild.channels.filter { $0.parentID?.uint64 == channelRef.id && $0.overwrites.isChannelVisible(for: userID) }
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
    let userID = delegate?.navigatorViewController(self, didRequestCurrentUserID: ())

    if item == nil {
      return NavigatorOutlineItem.rootItems.count
    }

    switch item {
    case let item as NavigatorOutlineItem:
      switch item.kind {
      case .section:
        switch item.id {
        case "pinned": return 0
        case "dms": return privateChannelIDs.count
        case "guilds": return guildIDs.count
        default: preconditionFailure()
        }
      case .guild:
        let guild = guild(withID: Snowflake(string: item.id))
        return guild.sortedTopLevelChannels(forUserWith: userID).count
      }
    case let channel as ChannelRef:
      guard channel.type == .category,
            let guildID = channel.guildID else {
        return 0
      }
      let guild = guild(withID: Snowflake(uint64: guildID))
      return guild.channels.filter { $0.parentID?.uint64 == channel.id && $0.overwrites.isChannelVisible(for: userID) }.count
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
  func outlineView(_ outlineView: NSOutlineView, viewFor _: NSTableColumn?, item: Any) -> NSView? {
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
        let view = outlineView.makeView(withIdentifier: .navigatorGuild, owner: nil) as! NavigatorGuildCellView

        let snowflake = Snowflake(string: item.id)
        let guild = guild(withID: snowflake)
        view.textField?.stringValue = guild.name

        view.roundingView.radius = 6.0

        if let url = guild.icon?.url(withFileExtension: "png") {
          view.imageView?.kf.setImage(with: url)
        }

        return view
      }
    case let channelRef as ChannelRef:
      // TODO: don't use .navigatorGuild
      let view = outlineView.makeView(withIdentifier: .navigatorGuild, owner: nil) as! NavigatorGuildCellView

      if channelRef.isPrivate {
        let privateChannel = privateChannel(withID: Snowflake(uint64: channelRef.id))
        view.textField?.stringValue = privateChannel.name()

        if case .groupDM(let groupDMChannel) = privateChannel {
          if let url = groupDMChannel.icon?.url(withFileExtension: "png") {
            view.imageView?.kf.setImage(with: url)
            view.roundingView.radius = 6.0
          } else {
            view.imageView?.image = NSImage(systemSymbolName: "person.2.fill", accessibilityDescription: "Group Direct Message")
            view.roundingView.radius = 0
          }
        } else {
          // TODO: implement caching, then use the recipient's avatar here
          view.imageView?.image = NSImage(systemSymbolName: "person.fill", accessibilityDescription: "Direct Message")
          view.roundingView.radius = 0
        }
      } else {
        guard let guildID = channelRef.guildID else {
          NSLog("[warning] non-private channelref didn't have guild id")
          return nil
        }
        view.roundingView.radius = 0.0
        let guild = guild(withID: Snowflake(uint64: guildID))

        let channelID = Snowflake(uint64: channelRef.id)
        let channel = guild.channels.first(where: { $0.id == channelID })!

        view.imageView?.image = NSImage(
          systemSymbolName: channel.type.systemSymbolName,
          accessibilityDescription: nil
        )
        view.textField?.stringValue = channel.name
      }

      return view
    default:
      return nil
    }
  }

  func outlineView(_: NSOutlineView, shouldSelectItem item: Any) -> Bool {
    if let channel = item as? ChannelRef {
      return channel.type == .text || channel.isPrivate
    }

    return false
  }

  func outlineViewSelectionDidChange(_: Notification) {
    guard outlineView.selectedRow > 0 else { return }

    let channel = outlineView.item(atRow: outlineView.selectedRow) as! ChannelRef

    delegate?.navigatorViewController(
      self,
      didSelectChannelWithID: Snowflake(uint64: channel.id),
      inGuildWithID: channel.guildID.map { Snowflake(uint64: $0) }
    )
  }

  func outlineView(_: NSOutlineView,
                   tintConfigurationForItem _: Any) -> NSTintConfiguration?
  {
    .monochrome
  }
}
