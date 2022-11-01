import Cocoa
import SwiftyJSON

enum JSONInspectorError: Error {
  case failedToStringifyJSON
}

final class JSONInspectorViewController: NSViewController {
  @IBOutlet var outlineView: NSOutlineView!
  // NSOutlineView doesn't retain its menu? :thinking:
  @IBOutlet var outlineViewMenu: NSMenu!
  @IBOutlet var copyJSONValueMenuItem: NSMenuItem!
  @IBOutlet var copyJSONObjectEntryValueMenuItem: NSMenuItem!

  var jsonData: JSON?

  override func viewDidLoad() {
    super.viewDidLoad()
    outlineView.dataSource = self
    outlineView.delegate = self
    if jsonData != nil {
      reloadData()
    }
  }

  func reloadData() {
    outlineView.reloadData()

    // Automatically expand the first row.
    if jsonData != nil, let item = outlineView.item(atRow: 0) {
      outlineView.expandItem(item)
    }
  }

  @IBAction func copyClickedJSONValue(_: Any) {
    guard outlineView.clickedRow > -1,
          let item = outlineView.item(atRow: outlineView.clickedRow)
    else {
      return
    }

    NSPasteboard.general.clearContents()
    let copyingValue: Data
    do {
      switch item {
      case let objectPair as JSONObjectPair:
        copyingValue = try objectPair.value.encoded()
      case let arrayValue as JSONArrayValue:
        copyingValue = try arrayValue.value.encoded()
      case let json as JSON:
        copyingValue = try json.encoded()
      default:
        preconditionFailure("tried to copy unknown inspector item")
      }

      guard let string = String(data: copyingValue, encoding: .utf8) else {
        throw JSONInspectorError.failedToStringifyJSON
      }

      NSPasteboard.general.setString(string, forType: .string)
    } catch {
      presentError(error)
    }
  }
}

extension JSONInspectorViewController: NSMenuItemValidation {
  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    if menuItem.action == #selector(copyClickedJSONValue) {
      return outlineView.clickedRow > -1
    }

    return false
  }
}

struct JSONObjectPair {
  let key: String
  let value: JSON
}

struct JSONArrayValue {
  let index: Int
  let value: JSON
}

/// Downcasts `Any` into some kind of optionally keyed JSON value.
private func downcastJSON(_ item: Any) -> (key: String?, value: JSON)? {
  switch item {
  case let json as JSON: return (key: nil, value: json)
  case let objectPair as JSONObjectPair: return (key: objectPair.key, value: objectPair.value)
  case let arrayValue as JSONArrayValue: return (key: String(arrayValue.index), value: arrayValue.value)
  default: return nil
  }
}

private extension JSON {
  /// A terse string representing this JSON value.
  ///
  /// Returns `nil` for dictionaries and arrays.
  var stringified: String {
    switch type {
    case .array:
      let elements = array!.count
      return "\(elements) array element\(elements == 1 ? "" : "s")"
    case .dictionary:
      let pairs = dictionary!.count
      return "\(pairs) object value\(pairs == 1 ? "" : "s")"
    case .string: return "\"\(string!)\""
    case .bool: return bool! ? "true" : "false"
    case .number: return String(int!)
    case .null: return "(null)"
    default: return "(unknown)"
    }
  }

  /// Returns a system image name representing this JSON value.
  var systemImage: String {
    switch type {
    case .array: return "list.number"
    case .dictionary: return "curlybraces"
    case .string: return "textformat.size"
    case .bool: return "seal.fill"
    case .number: return "textformat.123"
    case .null: return "sparkle"
    default: return "questionmark.circle.fill"
    }
  }
}

extension JSONInspectorViewController: NSOutlineViewDataSource {
  func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
    guard let item else {
      return jsonData!
    }

    guard case let (_, json)? = downcastJSON(item) else {
      preconditionFailure("JSON inspector child was not JSON")
    }

    switch json.type {
    case .dictionary:
      let dictionary = json.dictionary!
      let sortedKeys = dictionary.keys.sorted()
      let key = sortedKeys[index]
      return JSONObjectPair(key: key, value: dictionary[key]!)
    case .array:
      let array = json.array!
      return JSONArrayValue(index: index, value: array[index])
    default: preconditionFailure("Attempted to resolve child \(index) for a non-sequence JSON value")
    }
  }

  func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    guard let item else {
      return jsonData == nil ? 0 : 1
    }

    guard case let (_, json)? = downcastJSON(item) else {
      return 0
    }

    switch json.type {
    case .dictionary: return json.dictionary!.count
    case .array: return json.array!.count
    default: return 0
    }
  }

  func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
    guard case let (_, json)? = downcastJSON(item) else {
      preconditionFailure("Item was not JSON-like - while determining expandability of item")
    }

    switch json.type {
    case .dictionary: return json.dictionary!.count > 0
    case .array: return json.array!.count > 0
    default: return false
    }
  }
}

extension JSONInspectorViewController: NSOutlineViewDelegate {
  func outlineView(_ outlineView: NSOutlineView, viewFor _: NSTableColumn?, item: Any) -> NSView? {
    let view = outlineView.makeView(withIdentifier: .init("json"), owner: nil) as! NSTableCellView

    guard case let (key, json)? = downcastJSON(item) else {
      preconditionFailure("Item was not JSON-like - while populating view")
    }

    var attributedString = AttributedString()

    if let key {
      let keyAttributedString = AttributedString(
        key + ": ",
        attributes: .init([.font: NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize)])
      )
      attributedString.append(keyAttributedString)
    }

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = .byTruncatingTail
    attributedString.paragraphStyle = paragraphStyle
    attributedString.append(AttributedString(json.stringified))

    view.textField?.attributedStringValue = NSAttributedString(attributedString)
    view.imageView?.image = NSImage(systemSymbolName: json.systemImage, accessibilityDescription: String(describing: json.type))

    return view
  }
}
