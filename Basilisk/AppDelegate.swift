import Cocoa
import Combine
import Serpent

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  var gatewayLogStore = LogStore()

  /// The application's active sessions.
  var sessions: [Session] = []

  var managedChatWindowControllers: [ChatWindowController] = []

  var windowManagementCancellables: Set<AnyCancellable> = []
  var loggingCancellables: Set<AnyCancellable> = []

  var activeViewControllers: [ChatViewController] {
    NSApp.windows.compactMap { $0.contentViewController as? ChatViewController }
  }

  func createSession(withAccount account: Account) -> Session {
    let client = Client(baseURL: account.baseURL, token: account.token)
    let session = Session(account: account, client: client)
    sessions.append(session)
    client.http.subject.receive(on: DispatchQueue.main)
      .sink { [unowned self] log in
        Task { @MainActor in
          let message = LogMessage(direction: .sent, timestamp: Date.now, variant: .http(log))
          gatewayLogStore.appendMessage(message)
        }
      }
      .store(in: &windowManagementCancellables)
    NSLog("added session: %@ (# sessions is now %d)", String(describing: session), sessions.count)
    return session
  }

  func createManagedChatWindow(associatingWithSession session: Session? = nil, immediatelyLoading immediatelyLoad: Bool) -> ChatWindowController {
    let windowController = NSStoryboard(name: "Main", bundle: Bundle.main)
      .instantiateController(withIdentifier: .init("chat")) as! ChatWindowController
    let chatController = windowController.contentViewController as! ChatViewController
    if let session {
      chatController.associateWithSession(session, immediatelyLoading: immediatelyLoad)
    }
    managedChatWindowControllers.append(windowController)
    NotificationCenter.default.publisher(for: NSWindow.willCloseNotification, object: windowController.window!)
      .sink { [unowned self] notification in
        let window = notification.object as! NSWindow
        NSLog("%@ has closed, removing from managed window controllers", window)
        guard let index = managedChatWindowControllers.firstIndex(of: window.windowController as! ChatWindowController) else {
          NSLog("failed to find managed window controller for %@", window)
          return
        }
        managedChatWindowControllers.remove(at: index)
        NSLog("now have %d managed window controllers", managedChatWindowControllers.count)
      }
      .store(in: &windowManagementCancellables)
    return windowController
  }

  func applicationDidFinishLaunching(_: Notification) {
    do {
      if FileManager.default.fileExists(atPath: Accounts.defaultAccountsPath.path) {
        NSLog("reading accounts")
        try Accounts.read()
      }
    } catch {
      NSApp.presentError(CocoaError(.fileReadCorruptFile,
                                    userInfo: [NSURLErrorKey: Accounts.defaultAccountsPath]))
    }

    if let account = Accounts.accounts.first?.value,
       UserDefaults.standard.bool(forKey: "BSLKAutomaticallyAuthorizeWithFirstAccount")
    {
      NSLog("automatically creating session with account: \(account.name)")
      Task {
        do {
          let session = createSession(withAccount: account)
          try await session.client.http.requestLandingPage()
          session.client.connect(gatewayURL: account.gatewayURL)

          Task { @MainActor in
            let windowController = createManagedChatWindow(associatingWithSession: session, immediatelyLoading: false)
            windowController.window!.makeKeyAndOrderFront(nil)
          }
        } catch {
          NSLog("failed to connect: %@", String(describing: error))
          let _ = await NSApp.presentError(error)
        }
      }
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
