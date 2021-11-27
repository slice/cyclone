import Contempt

/// A channel reference wrapper. This is used to maintain equality check
/// consistency with `NSOutlineView`, which relies on `isEqual` from `NSObject`.
class ChannelRef: NSObject {
  public let guildID: UInt64
  public let id: UInt64
  public let name: String
  public let type: ChannelType
  public let parentID: UInt64?
  public let overwrites: [PermissionOverwrites]

  var isTopLevel: Bool {
    type == .category || parentID == nil
  }

  init(guild: Guild, channel: Channel) {
    guildID = guild.id.uint64
    id = channel.id.uint64
    type = channel.type
    parentID = channel.parentID.map(\.uint64)
    name = channel.name
    overwrites = channel.overwrites
  }

  override func isEqual(_ object: Any?) -> Bool {
    if let channel = object as? ChannelRef, channel.guildID == guildID,
       channel.id == id, channel.name == name, channel.parentID == parentID
    {
      return true
    }

    return false
  }
}
