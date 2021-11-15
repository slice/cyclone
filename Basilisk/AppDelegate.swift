import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  var gatewayLogStore = GatewayLogStore()

  func applicationDidFinishLaunching(_: Notification) {
    // Insert code here to initialize your application
  }

  @MainActor func applicationWillTerminate(_: Notification) {
    for window in NSApp.windows {
      if let viewController = window.contentViewController as? ViewController {
        NSLog(
          "attempting to disconnect client contained within \(viewController)"
        )

        // TODO(skip): This should be made synchronous somehow, because we can't
        // otherwise guarantee the execution of this task before the application
        // terminates. (And indeed, this doesn't actually seem to execute in
        // time. Oh well.)
        Task {
          try! await viewController.tearDownClient()
        }
      }
    }
  }

  func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
    true
  }
}
