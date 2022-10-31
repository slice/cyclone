import Serpent

// Discord channel sorting is complicated. To do it, assume that each channel is
// within a category. (Any channel that isn't within a category can be assumed
// to be in a special category that is always ordered first.)
//
// To begin, sort the categories themselves by ascending position, falling
// back to the ID if no position is present [1]. Within each category, sort the
// channels according to their type [2], position, then ID.
//
// [1]: Although the position property is marked as optional in the
//      documentation, this doesn't seem to be true in practice.
//      See: https://github.com/discord/discord-api-docs/issues/4613#issuecomment-1063254358
// [2]: Channels of different types cannot be interleaved. Notice that voice
//      channels must be positioned below text channels.
//
// Assume positions to only be unique within each combination of category and
// type. It is important to know that positions are not globally unique.
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
// Kudos to Danny#0007 and friends in the Dannyware server for their assistance.

public extension Array where Element == GuildChannel {
  /// Sorts an array of channels according to their type, then position, then
  /// ID.
  func sortedByTypeAndPosition() -> [GuildChannel] {
    sorted {
      ($0.type.rawValue, $0.position, $0.id) < ($1.type.rawValue, $1.position, $1.id)
    }
  }

  func withinCategory(_ category: GuildChannel) -> [GuildChannel] {
    filter { $0.parentID == category.id }
  }
}

public extension Guild {
  /// Returns an array of this guild's top level channels, sorted according to
  /// how they are displayed in the client for this user.
  func sortedTopLevelChannels(forUserWith userID: Snowflake?) -> [GuildChannel] {
    channels
      .filter {
        ($0.isTopLevel) && $0.overwrites.isChannelVisible(for: userID)
      }
      .sortedByTypeAndPosition()
  }
}
