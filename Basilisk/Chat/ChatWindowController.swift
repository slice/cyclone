import Cocoa

final class ChatWindowController: NSWindowController {
  @IBAction override func newWindowForTab(_ sender: Any?) {
    let currentSession = (contentViewController as? ChatViewController)?.session
    let delegate = NSApp.delegate as! AppDelegate
    let windowController = delegate.createManagedChatWindow(associatingWithSession: currentSession, immediatelyLoading: true)
    let window = windowController.window!
    self.window!.addTabbedWindow(window, ordered: .above)
    window.makeKeyAndOrderFront(self)
  }
}
