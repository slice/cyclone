import Foundation

/// A navigator outline item.
///
/// Objects of this type are returned as "items" by the outline view's delegate
/// and data source. They are representative of either the root sections
/// (pinned, direct messages, and guilds), or guilds themselves. Both can be
/// expanded to reveal channels (and additionally categories in the case of
/// guilds).
///
/// This class is a reference type in order to maintain the `NSObject` identity
/// semantics that `NSOutlineView` desires.
class NavigatorOutlineItem: NSObject {
  /// The root navigator items.
  public static let rootItems: [NavigatorOutlineItem] = [
    NavigatorOutlineItem(kind: .section, id: "pinned"),
    NavigatorOutlineItem(kind: .section, id: "dms"),
    NavigatorOutlineItem(kind: .section, id: "guilds"),
  ]

  public enum Kind: Hashable {
    /// A root section (pinned, direct messages, or guilds).
    case section

    /// A Discord guild.
    case guild
  }

  public let kind: Kind

  /// A unique identifier for the item.
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
