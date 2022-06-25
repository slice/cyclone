import Cocoa
import Serpent
import OrderedCollections

class HTTPInspectorController: NSViewController {
  @IBOutlet var requestSummaryLabel: NSTextField!
  @IBOutlet var responseSummaryLabel: NSTextField!
  @IBOutlet var requestResponseTabView: NSTabView!

  var requestDetailController: HTTPInspectorBodyHeadersController {
    children[0] as! HTTPInspectorBodyHeadersController
  }

  var responseDetailController: HTTPInspectorBodyHeadersController {
    children[1] as! HTTPInspectorBodyHeadersController
  }

  var log: HTTPLog? {
    didSet {
      updateSummaries()
      guard let log = log else { return }
      requestDetailController.headers = OrderedDictionary(log.requestHeaders, uniquingKeysWith: { first, second in first })
      requestDetailController.body = log.requestBody ?? .empty
      responseDetailController.headers = OrderedDictionary(log.responseHeaders, uniquingKeysWith: { first, second in first })
      responseDetailController.body = log.responseBody ?? .empty
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
  }

  func updateSummaries() {
    guard let log = log else { return }

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = .byTruncatingTail
    let requestSummary = NSMutableAttributedString()
    let size = NSFont.preferredFont(forTextStyle: .title1).pointSize
    requestSummary.append(NSAttributedString(string: log.method.rawValue + " ", attributes: [.font: NSFont.boldSystemFont(ofSize: size)]))
    requestSummary.append(NSAttributedString(string: log.url.absoluteString))
    requestSummary.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: requestSummary.length))
    requestSummaryLabel.attributedStringValue = requestSummary

    responseSummaryLabel.stringValue = "HTTP \(log.statusCode)"
  }
}
