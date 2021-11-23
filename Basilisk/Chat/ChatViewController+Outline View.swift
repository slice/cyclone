import Cocoa
import Contempt

/// A channel reference wrapper. This is used to ensure equality check
/// consistency with `NSOutlineView`.
class ChannelRef: NSObject {
  public let id: UInt64
  public let name: String
  public let type: ChannelType
  public let parentID: UInt64?

  var isTopLevel: Bool {
    type == .category || parentID == nil
  }

  init(channel: Channel) {
    id = channel.id.uint64
    type = channel.type
    parentID = channel.parentID.map(\.uint64)
    name = channel.name
  }
}

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

private extension NSUserInterfaceItemIdentifier {
  static let channel: Self = .init("channel")
}

extension ChatViewController: NSOutlineViewDataSource {
  func outlineView(_: NSOutlineView, child index: Int,
                   ofItem item: Any?) -> Any
  {
    if item == nil {
      guard let topLevelChannels = selectedGuild?.sortedTopLevelChannels
      else { return NSNull() }
      let channel = topLevelChannels[index]
      return ChannelRef(channel: channel)
    } else if let channel = item as? ChannelRef {
      guard let channels = selectedGuild?.channels else { return NSNull() }

      let sortedChannels = channels
        .filter { $0.parentID?.uint64 == channel.id }
        .sortedByTypeAndPosition()
      return ChannelRef(channel: sortedChannels[index])
    }

    return NSNull()
  }

  func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    if item == nil {
      return selectedGuild?.sortedTopLevelChannels.count ?? 0
    } else if let channel = item as? ChannelRef {
      guard channel.type == .category else { return 0 }
      return selectedGuild?.channels
        .filter { $0.parentID?.uint64 == channel.id }.count ?? 0
    }

    return 0
  }

  func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
    if let item = item as? ChannelRef, item.type == .category {
      return true
    }

    return false
  }
}

extension ChatViewController: NSOutlineViewDelegate {
  func outlineView(_ outlineView: NSOutlineView, viewFor _: NSTableColumn?,
                   item: Any) -> NSView?
  {
    let cell = outlineView.makeView(
      withIdentifier: .channel,
      owner: nil
    ) as! NSTableCellView
    let channel = (item as! ChannelRef)
    var name = channel.name
    if channel.type != .category {
      name = "#" + name
    }
    cell.textField!.stringValue = name
    return cell
  }

  func outlineViewSelectionDidChange(_: Notification) {
    guard let item = channelsOutlineView
      .item(atRow: channelsOutlineView.selectedRow) as? ChannelRef
    else { return }
    focusedChannelID = item.id
  }
}
