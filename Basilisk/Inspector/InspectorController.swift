import Cocoa
import Combine

class InspectorController: NSSplitViewController {
  var logStore: LogStore {
    let delegate = NSApp.delegate as! AppDelegate
    return delegate.gatewayLogStore
  }

  var messagesSink: AnyCancellable!

  var messagesViewController: InspectorMessagesController! {
    splitViewItems[0].viewController as? InspectorMessagesController
  }

  var detailTabViewController: NSTabViewController! {
    splitViewItems[1].viewController as? NSTabViewController
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    messagesSink = logStore.newMessages.sink { [weak self] _ in
      self?.updateSubtitle()
    }

    messagesViewController.onSelectedMessage = { [weak self] logMessageID in
      guard let self = self else { return }

      guard let logMessageID = logMessageID,
            let message = self.logStore.messages.first(where: { $0.id == logMessageID }) else {
        // Show the empty state if nothing is selected.
        self.detailTabViewController.tabView.selectTabViewItem(at: 2)
        return
      }

      switch message.variant {
      case .http(let http):
        let httpItem = self.detailTabViewController.tabViewItems[0]
        let httpInspectorVC = httpItem.viewController! as! HTTPInspectorController
        httpInspectorVC.log = http
        self.detailTabViewController.tabView.selectTabViewItem(httpItem)
      case .gateway(let packet):
        let inspectorItem = self.detailTabViewController.tabViewItems[1]
        let jsonInspectorVC = inspectorItem.viewController! as! JSONInspectorViewController
        jsonInspectorVC.jsonData = packet.packet.eventData
        jsonInspectorVC.reloadData()
        self.detailTabViewController.tabView.selectTabViewItem(inspectorItem)
      }
    }
  }

  override func viewDidAppear() {
    updateSubtitle()
  }

  private func updateSubtitle() {
    let count = logStore.messages.count
    let s = count == 1 ? "" : "s"
    view.window?.subtitle = "\(count) message\(s)"
  }

}
