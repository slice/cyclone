import AppKit
import Serpent

@MainActor protocol NavigatorViewControllerDelegate: AnyObject {
  /// Invoked whenever a channel was selected.
  func navigatorViewController(_ navigatorViewController: NavigatorViewController,
                               didSelectChannelWithID: GuildChannel.ID,
                               inGuildWithID: Guild.ID?)

  /// Called whenever the navigator view controller needs more information about
  /// a certain guild.
  func navigatorViewController(_ navigatorViewController: NavigatorViewController,
                               requestingGuildWithID: Guild.ID) -> Guild

  /// Asks the delegate for more information about a private channel.
  func navigatorViewController(_ navigatorViewController: NavigatorViewController,
                               requestingPrivateChannelWithID: PrivateChannel.ID) -> PrivateChannel

  /// Called whenever the navigator view controller needs the currently logged
  /// in user's ID.
  func navigatorViewController(_ navigatorViewController: NavigatorViewController,
                               didRequestCurrentUserID: Void) -> Snowflake?
}
