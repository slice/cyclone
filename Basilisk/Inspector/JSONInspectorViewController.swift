import Cocoa
import SwiftyJSON

final class JSONInspectorViewController: NSViewController {
  @IBOutlet var outlineView: NSOutlineView!

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
fileprivate func downcastJSON(_ item: Any) -> (key: String?, value: JSON)? {
  switch item {
  case let json as JSON: return (key: nil, value: json)
  case let objectPair as JSONObjectPair: return (key: objectPair.key, value: objectPair.value)
  case let arrayValue as JSONArrayValue: return (key: String(arrayValue.index), value: arrayValue.value)
  default: return nil
  }
}

fileprivate extension JSON {
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
  func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
    guard let item = item else {
      return jsonData!
    }

    guard case (_, let json)? = downcastJSON(item) else {
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

  func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    guard let item = item else {
      return jsonData == nil ? 0 : 1
    }

    guard case (_, let json)? = downcastJSON(item) else {
      return 0
    }

    switch json.type {
    case .dictionary: return json.dictionary!.count
    case .array: return json.array!.count
    default: return 0
    }
  }

  func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
    guard case (_, let json)? = downcastJSON(item) else {
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
  func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
    let view = outlineView.makeView(withIdentifier: .init("json"), owner: nil) as! NSTableCellView

    guard case (let key, let json)? = downcastJSON(item) else {
      preconditionFailure("Item was not JSON-like - while populating view")
    }

    var attributedString = AttributedString()

    if let key = key {
      var keyAttributedString = AttributedString(key + ": ")
      keyAttributedString[AttributeScopes.AppKitAttributes.FontAttribute.self] = NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize)
      attributedString.append(keyAttributedString)
    }

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = .byTruncatingTail
    attributedString[AttributeScopes.AppKitAttributes.ParagraphStyleAttribute.self] = paragraphStyle
    attributedString.append(AttributedString(json.stringified))

    view.textField?.attributedStringValue = NSAttributedString(attributedString)
    view.imageView?.image = NSImage(systemSymbolName: json.systemImage, accessibilityDescription: String(describing: json.type))

    return view
  }
}
