import Foundation
import Tempest

/// A channel reference wrapper.
///
/// Objects of this type are returned as "items" by the outline view's delegate
/// and data source. They are representative of channels (including categories)
/// within a guild.
///
/// This class is a reference type in order to maintain the `NSObject` identity
/// semantics that `NSOutlineView` desires.
class ChannelRef: NSObject {
  public let guildID: UInt64?
  public let id: UInt64
  public let name: String?
  public let type: ChannelType
  public let parentID: UInt64?
  public let overwrites: [PermissionOverwrites]

  /// Returns whether the channel is not within a category, or is a category
  /// itself.
  var isTopLevel: Bool {
    type == .category || parentID == nil
  }

  var isPrivate: Bool {
    type == .dm || type == .groupDM
  }

  init(privateChannel: PrivateChannel) {
    guildID = nil
    name = nil
    id = privateChannel.id.uint64
    type = privateChannel.type
    parentID = nil
    overwrites = []
  }

  init(guild: Guild, channel: GuildChannel) {
    guildID = guild.id.uint64
    id = channel.id.uint64
    type = channel.type
    parentID = channel.parentID.map(\.uint64)
    name = channel.name
    overwrites = channel.overwrites
  }

  override func isEqual(_ object: Any?) -> Bool {
    if let channel = object as? ChannelRef, channel.id == id {
      return true
    }

    return false
  }
}
