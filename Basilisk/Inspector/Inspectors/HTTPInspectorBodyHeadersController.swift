import Cocoa
import OrderedCollections
import SwiftyJSON

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

  private var body: Data = .empty

  func populateBody(body: Data, isJSON: Bool = false) {
    if isJSON, let json = try? JSON(data: body) {
      jsonInspectorController.jsonData = json
      jsonInspectorController.reloadData()
      bodyTabView.selectTabViewItem(at: 1)
      return
    }

    guard let string = String(data: body, encoding: .utf8) else {
      bodyTextView.string = "<binary data>"
      return
    }

    bodyTextView.string = string
    bodyTabView.selectTabViewItem(at: 0)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    headersTableView.dataSource = self
    headersTableView.delegate = self
    bodyTextView.font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
  }

  @IBAction func copyValueOfClickedHeader(_ sender: Any) {
    guard headersTableView.clickedRow >= 0 else {
      return
    }
    let header = headers.elements[headersTableView.clickedRow]
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(header.value, forType: .string)
  }

  @IBAction func copyNameAndValueOfClickedHeader(_ sender: Any) {
    guard headersTableView.clickedRow >= 0 else {
      return
    }
    let header = headers.elements[headersTableView.clickedRow]
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString("\(header.key): \(header.value)", forType: .string)
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
