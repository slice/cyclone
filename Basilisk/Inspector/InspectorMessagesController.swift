import Cocoa
import Combine

enum GatewayInspectorSection {
  case main
}

fileprivate extension NSUserInterfaceItemIdentifier {
  static let timestamp: Self = .init("timestamp")
  static let direction: Self = .init("direction")
  static let gatewaySequence: Self = .init("gatewaySequence")
  static let summary: Self = .init("summary")
}

class InspectorMessagesController: NSViewController {
  var logStore: LogStore {
    let delegate = NSApp.delegate as! AppDelegate
    return delegate.gatewayLogStore
  }

  @IBOutlet var tableView: NSTableView!
  var dataSource: NSTableViewDiffableDataSource<
    GatewayInspectorSection,
    LogMessage.ID
  >!
  var messagesSink: AnyCancellable!

  var onSelectedMessage: ((LogMessage.ID?) -> Void)?

  override func viewDidLoad() {
    super.viewDidLoad()

    dataSource = NSTableViewDiffableDataSource(
      tableView: tableView
    ) { [weak self] tableView, tableColumn, _, identifier in
      guard let message = (self?.logStore.messages.first { $0.id == identifier }) else {
        return NSView()
      }

      if tableColumn.identifier == .summary {
        let view = tableView.makeView(withIdentifier: .summary, owner: nil) as! InspectorSummaryCellView
        view.setup(logMessage: message)
        return view
      }

      let view = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as! NSTableCellView
      view.textField?.stringValue = ""

      switch tableColumn.identifier {
      case .timestamp:
        let timestamp = message.timestamp.formatted(date: .omitted, time: .standard)
        view.textField?.stringValue = timestamp
      case .gatewaySequence:
        if case .gateway(let packet) = message.variant {
          view.textField?.stringValue = packet.packet.sequence.map { String(Int($0)) } ?? ""
        } else {
          view.textField?.stringValue = ""
        }
        view.textField?.alignment = .center
      case .direction:
        let image = NSImage(
          systemSymbolName: message.direction.systemImageName,
          accessibilityDescription: message
            .direction == .received ? "Received" : "Sent"
        )!
        view.imageView?.image = image
      default:
        break
      }

      return view
    }
    tableView.dataSource = dataSource

    applyInitialSnapshot()
    messagesSink = logStore.newMessages.receive(on: RunLoop.main)
      .sink { [weak self] message in
        guard let self = self else { return }
        var snapshot = self.dataSource.snapshot()
        snapshot.appendItems([message.id])
        self.dataSource.apply(snapshot, animatingDifferences: true)
      }

    self.applyInitialSnapshot(animatingDifferences: false)
  }

  func applyInitialSnapshot(animatingDifferences: Bool = false) {
    var snapshot = NSDiffableDataSourceSnapshot<
      GatewayInspectorSection,
      LogMessage.ID
    >()
    snapshot.appendSections([.main])
    snapshot.appendItems(logStore.messages.map(\.id), toSection: .main)
    dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
  }
}

extension InspectorMessagesController: NSTableViewDelegate {
  func tableViewSelectionDidChange(_: Notification) {
    let selectedRow = tableView.selectedRow
    guard selectedRow >= 0 else {
      self.onSelectedMessage?(nil)
      return
    }

    let message = logStore.messages[selectedRow]
    self.onSelectedMessage?(message.id)
  }
}
