import Cocoa

class StatusBarContainerController: NSViewController {
  @IBOutlet var containedView: NSView!
  @IBOutlet var connectionStatusLabel: NSTextField!
  @IBOutlet var connectionStatus: ConnectionStatusView!

  override func viewDidLoad() {
    super.viewDidLoad()
    connectionStatusLabel.stringValue = ""
  }

  var containedViewController: NSViewController {
    children.first!
  }
}
