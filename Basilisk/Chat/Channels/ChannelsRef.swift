import Contempt

/// A channel reference wrapper. This is used to maintain equality check
/// consistency with `NSOutlineView`, which relies on `isEqual` from `NSObject`.
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
