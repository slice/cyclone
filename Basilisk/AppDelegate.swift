import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  var gatewayLogStore = GatewayLogStore()

  var activeViewControllers: [ChatViewController] {
    NSApp.windows.compactMap { $0.contentViewController as? ChatViewController }
  }

  func applicationDidFinishLaunching(_: Notification) {
    do {
      if FileManager.default.fileExists(atPath: Accounts.defaultAccountsPath.path) {
        try Accounts.read()
      }
    } catch {
      NSApp.presentError(CocoaError(.fileReadCorruptFile,
                                    userInfo: [NSURLErrorKey: Accounts.defaultAccountsPath]))
    }
  }

  @MainActor func applicationShouldTerminate(_ sender: NSApplication)
    -> NSApplication.TerminateReply
  {
    if activeViewControllers.isEmpty {
      return .terminateNow
    } else {
      Task {
        for activeViewController in activeViewControllers {
          NSLog(
            "trying to disconnect client in %@",
            String(describing: activeViewController)
          )
          do {
            try await activeViewController.client?.disconnect()
          } catch {
            NSLog("failed to disconnect vc: %@", error.localizedDescription)
          }
        }

        NSLog("ready to terminate now")
        sender.reply(toApplicationShouldTerminate: true)
      }

      NSLog("terminating later, there are active view controllers")
      return .terminateLater
    }
  }

  func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
    true
  }
}
