import AppKit
import Contempt

@MainActor protocol NavigatorViewControllerDelegate: AnyObject {
  func navigatorViewController(_ navigatorViewController: NavigatorViewController,
                               didSelectChannelWithID: Channel.ID,
                               inGuildWithID: Guild.ID)

  func navigatorViewController(_ navigatorViewController: NavigatorViewController,
                               requestingGuildWithID: Guild.ID) -> Guild

  func navigatorViewController(_ navigatorViewController: NavigatorViewController,
                               didRequestCurrentUserID: Void) -> Snowflake?
}
