import Cocoa
import Combine


class InspectorController: NSSplitViewController {
  var logStore: LogStore {
    let delegate = NSApp.delegate as! AppDelegate
    return delegate.gatewayLogStore
  }

  var messagesSink: AnyCancellable!

  override func viewDidLoad() {
    super.viewDidLoad()

    messagesSink = logStore.objectWillChange.sink { [weak self] _ in
      self?.updateSubtitle()
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
