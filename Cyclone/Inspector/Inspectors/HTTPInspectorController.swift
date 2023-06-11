import Cocoa
import OrderedCollections
import Tempest

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
      guard let log else { return }
      populateDetailController(requestDetailController, data: log.requestBody, headers: log.requestHeaders)
      populateDetailController(responseDetailController, data: log.responseBody, headers: log.responseHeaders)
    }
  }

  private func populateDetailController(_ controller: HTTPInspectorBodyHeadersController, data: Data?, headers: [String: String]) {
    if let data {
      let isJSON = headers["Content-Type"].map { $0 == "application/json" } ?? false
      controller.populateBody(body: data, isJSON: isJSON)
    }
    controller.headers = OrderedDictionary(headers, uniquingKeysWith: { first, _ in first })
  }

  override func viewDidLoad() {
    super.viewDidLoad()
  }

  func updateSummaries() {
    guard let log else { return }

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
