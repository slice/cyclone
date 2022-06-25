import Cocoa
import OrderedCollections

class HTTPInspectorBodyHeadersController: NSViewController {
  @IBOutlet var headersTableView: NSTableView!
  @IBOutlet var bodyLabel: NSTextField!
  @IBOutlet var bodyTextView: NSTextView!
  @IBOutlet var bodyTabView: NSTabView!

  var jsonInspectorController: JSONInspectorViewController {
    children[0] as! JSONInspectorViewController
  }

  var headers: OrderedDictionary<String, String> = [:] {
    didSet {
      headersTableView.reloadData()
    }
  }

  var body: Data = .empty {
    didSet {
      updateBody()
    }
  }

  func updateBody() {
    guard let string = String(data: body, encoding: .utf8) else {
      bodyTextView.string = "<binary data>"
      return
    }

    bodyTextView.string = string
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    headersTableView.dataSource = self
    headersTableView.delegate = self
    bodyTextView.font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
  }
}

extension HTTPInspectorBodyHeadersController: NSTableViewDataSource {
  func numberOfRows(in tableView: NSTableView) -> Int {
    headers.count
  }
}

extension HTTPInspectorBodyHeadersController: NSTableViewDelegate {
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard let tableColumn = tableColumn else { return nil }
    let view = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as! NSTableCellView
    let header = headers.elements[row]
    view.textField?.stringValue = tableColumn.identifier.rawValue == "name" ? header.key : header.value
    return view
  }
}
