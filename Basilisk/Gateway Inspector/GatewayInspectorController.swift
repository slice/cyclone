import Cocoa
import Combine

enum GatewayInspectorSection {
  case main
}

extension NSUserInterfaceItemIdentifier {
  static let timestamp: Self = .init("timestamp")
  static let direction: Self = .init("direction")
  static let opcode: Self = .init("opcode")
  static let sequence: Self = .init("sequence")
  static let eventName: Self = .init("eventName")
}

class GatewayInspectorController: NSViewController {
  var gatewayLogStore: GatewayLogStore {
    let delegate = NSApp.delegate as! AppDelegate
    return delegate.gatewayLogStore
  }

  @IBOutlet var messagesTableView: NSTableView!
  @IBOutlet var messageDetailView: NSTextView!
  var dataSource: NSTableViewDiffableDataSource<
    GatewayInspectorSection,
    LogMessage.ID
  >!
  var messagesSink: AnyCancellable!

  override func viewDidLoad() {
    super.viewDidLoad()

    dataSource = NSTableViewDiffableDataSource(
      tableView: messagesTableView
    ) { [weak self] _, tableColumn, _, identifier in
      let message = (self?.gatewayLogStore.messages
        .first { $0.id == identifier })!
      var text: String?
      switch tableColumn.identifier {
      case .timestamp:
        text = message.timestamp.formatted(date: .omitted, time: .standard)
      case .direction:
        let image = NSImage(
          systemSymbolName: message.direction.systemImageName,
          accessibilityDescription: message
            .direction == .received ? "Received" : "Sent"
        )!
        return NSImageView(image: image)
      case .opcode:
        text = message.gatewayPacket.map { String(describing: $0.op) }
      case .sequence:
        text = message.gatewayPacket?.sequence.map { String(Int($0)) }
      case .eventName:
        text = message.gatewayPacket?.eventName
      default:
        break
      }

      if let text = text {
        let textField = NSTextField(labelWithString: text)
        return textField
      } else {
        return NSView()
      }
    }

    messageDetailView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

    messagesTableView.dataSource = dataSource
    messagesTableView.delegate = self

    applyInitialSnapshot()
    messagesSink = gatewayLogStore.objectWillChange.receive(on: RunLoop.main)
      .sink { [weak self] _ in
        self?.updateSubtitle()
        self?.applyInitialSnapshot(animatingDifferences: true)
      }
  }

  override func viewDidAppear() {
    updateSubtitle()
  }

  private func updateSubtitle() {
    let count = gatewayLogStore.messages.count
    let s = count == 1 ? "" : "s"
    view.window?.subtitle = "\(count) message\(s)"
  }

  func applyInitialSnapshot(animatingDifferences: Bool = false) {
    var snapshot = NSDiffableDataSourceSnapshot<
      GatewayInspectorSection,
      LogMessage.ID
    >()
    snapshot.appendSections([.main])
    snapshot.appendItems(gatewayLogStore.messages.map(\.id), toSection: .main)
    dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
  }
}

extension GatewayInspectorController: NSTableViewDelegate {
  func tableViewSelectionDidChange(_: Notification) {
    let selectedRow = messagesTableView.selectedRow
    guard selectedRow > 0 else { return }
    let message = gatewayLogStore.messages[selectedRow]
    messageDetailView.string = message.gatewayPacket?
      .rawPayload ?? "<no packet>"
  }
}
