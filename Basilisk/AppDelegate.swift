import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  var gatewayLogStore = GatewayLogStore()

  var activeViewControllers: [ViewController] {
    NSApp.windows.compactMap { $0.contentViewController as? ViewController }
  }

  func applicationDidFinishLaunching(_: Notification) {
    // Insert code here to initialize your application
  }

  @MainActor func applicationShouldTerminate(_ sender: NSApplication)
    -> NSApplication.TerminateReply
  {
    if activeViewControllers.isEmpty {
      return .terminateNow
    } else {
      Task {
        for activeViewController in activeViewControllers {
          NSLog("trying to disconnect client in \(activeViewController)")
          try! await activeViewController.client?.disconnect()
        }

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
