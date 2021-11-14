import Cocoa
import Contempt
import FineJSON
import RichJSONParser

class ViewController: NSViewController {
  @IBOutlet var consoleTextView: NSTextView!
  @IBOutlet var inputTextField: NSTextField!
  @IBOutlet var consoleScrollView: NSScrollView!

  private var client: Client?
  private var focusedChannelID: UInt64?

  override func viewDidLoad() {
    super.viewDidLoad()
    consoleTextView.font = NSFont.userFixedPitchFont(ofSize: 10)
  }

  private func appendToConsole(line: String) {
    consoleTextView.string += line + "\n"

    let clipView = consoleScrollView.contentView
    let documentView = consoleScrollView.documentView!
    let isScrolledToBottom = clipView.bounds.origin.y + clipView.bounds
      .height == documentView.frame.height

    if isScrolledToBottom {
      consoleTextView.scrollToEndOfDocument(self)
    }
  }

  private func handleCommand(named command: String, arguments: [String]) {
    switch command {
    case "connect":
      guard let token = arguments.first else {
        appendToConsole(line: "[system] you need a user token, silly!")
        return
      }
      let tokenPreview =
        "\(token[token.startIndex ..< token.index(token.startIndex, offsetBy: 5)])..."
      appendToConsole(
        line: "[system] connecting to canary with token (\(tokenPreview))"
      )
      client = Client(branch: .canary, token: token)
      client!.delegate = self

      Task {
        guard let client = client else { return }
        try! await client.http.requestLandingPage()
        client.connect()
      }
    case "focus":
      guard let channelIDString = arguments.first,
            let channelID = UInt64(channelIDString)
      else {
        appendToConsole(line: "[system] provide a channel id... maybe...")
        return
      }

      focusedChannelID = channelID
      appendToConsole(line: "[system] focusing into <#\(channelID)>")
    default:
      appendToConsole(line: "[system] dunno what \"\(command)\" is!")
    }
  }

  @IBAction func inputTextFieldAction(_ sender: NSTextField) {
    let fieldText = sender.stringValue
    sender.stringValue = ""

    guard !fieldText.isEmpty else { return }

    if fieldText.starts(with: "/") {
      let tokens = fieldText.split(separator: " ")
      let firstToken = tokens.first!
      let firstTokenWithoutSlash =
        firstToken[firstToken.index(after: firstToken.startIndex) ..< firstToken
          .endIndex]
      handleCommand(
        named: String(firstTokenWithoutSlash),
        arguments: tokens.dropFirst().map { String($0) }
      )
      return
    }

    if let focusedChannelID = focusedChannelID, let client = client {
      let url = client.http.baseURL.appendingPathComponent("api")
        .appendingPathComponent("v9")
        .appendingPathComponent("channels")
        .appendingPathComponent(String(focusedChannelID))
        .appendingPathComponent("messages")
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      let randomNumber = Int.random(in: 0 ... 1_000_000_000)
      let json: JSON = .object(.init([
        "content": .string(fieldText),
        "tts": .boolean(false),
        "nonce": .string(String(randomNumber)),
      ]))
      let encoder = FineJSONEncoder()
      encoder.jsonSerializeOptions = JSONSerializeOptions(isPrettyPrint: false)
      encoder.optionalEncodingStrategy = .explicitNull
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try! encoder.encode(json)
      Task { [request] in
        try! await client.http.request(
          request,
          withSpoofedHeadersOfRequestType: .xhr
        )
      }
    }
  }
}

extension ViewController: ClientDelegate {
  nonisolated func clientReceivedGatewayPacket(_ packet: GatewayPacket<Any>) {
    Task {
      let logMessage = LogMessage(
        content: "op:\(packet.op) t:\(packet.eventName ?? "<none>") d:\(packet.data)",
        timestamp: Date.now,
        direction: .received
      )
      let delegate = await NSApp.delegate as! AppDelegate
      await delegate.gatewayLogStore.appendMessage(logMessage)

      if let eventName = packet.eventName, eventName == "MESSAGE_CREATE" {
        let data = packet.data as! [String: Any]

        let channelID = UInt64(data["channel_id"] as! String)
        guard await channelID == focusedChannelID else { return }
        let content = data["content"] as! String
        let author = data["author"] as! [String: Any]
        let username = author["username"] as! String
        let discriminator = author["discriminator"] as! String

        await self
          .appendToConsole(line: "<\(username)#\(discriminator)> \(content)")
        return
      }
    }
  }
}
