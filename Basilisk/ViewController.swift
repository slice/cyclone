import Cocoa
import Combine
import Contempt
import FineJSON
import RichJSONParser

@MainActor class ViewController: NSViewController {
  @IBOutlet var consoleTextView: NSTextView!
  @IBOutlet var inputTextField: NSTextField!
  @IBOutlet var consoleScrollView: NSScrollView!

  var client: Client?
  var focusedChannelID: UInt64?
  var gatewayPacketHandler: Task<Void, Never>?

  deinit {
    NSLog("ViewController deinit")

    // TODO(skip): The fact that disconnection happens asynchronously isn't
    // ideal, because it means that we can't guarantee a disconnect before
    // deinitializing. Is there a way to get around this?
    Task {
      try! await tearDownClient()
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    consoleTextView.font = NSFont.monospacedSystemFont(
      ofSize: 10,
      weight: .regular
    )
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

  private func connect(authorizingWithToken token: String) async throws {
    let truncatedToken =
      "\(token[token.startIndex ..< token.index(token.startIndex, offsetBy: 5)])..."
    appendToConsole(
      line: "[system] connecting to canary with token (\(truncatedToken))"
    )

    let client = Client(branch: .canary, token: token)
    self.client = client
    try await client.http.requestLandingPage()
    client.connect()
    setUpGatewayPacketHandler()
  }

  private func logPacket(_ packet: GatewayPacket) {
    let logMessage = LogMessage(
      content: packet.rawPayload,
      timestamp: Date.now,
      direction: .received
    )

    let delegate = NSApp.delegate as! AppDelegate
    delegate.gatewayLogStore.appendMessage(logMessage)
  }

  private func setUpGatewayPacketHandler() {
    guard let client = client else { return }

    gatewayPacketHandler = Task.detached(priority: .high) {
      for await packet in client.gatewayConnection.packets.bufferInfinitely()
        .values
      {
        await self.logPacket(packet)
        await self.handleGatewayPacket(packet)
      }
    }
  }

  private func handleGatewayPacket(_ packet: GatewayPacket) async {
    if let eventName = packet.eventName, eventName == "MESSAGE_CREATE" {
      let data = packet.eventData!.objectValue!

      let channelID = UInt64(data["channel_id"]!.stringValue!)
      guard channelID == focusedChannelID else { return }
      let content = data["content"]!.stringValue!
      let author = data["author"]!.objectValue!
      let username = author["username"]!.stringValue!
      let discriminator = author["discriminator"]!.stringValue!

      appendToConsole(line: "<\(username)#\(discriminator)> \(content)")
    }
  }

  /// Disconnect from the gateway and tear down the Discord client.
  func tearDownClient() async throws {
    NSLog("tearing down client")
    gatewayPacketHandler?.cancel()

    // Disconnect from the Discord gateway with a 1000 close code.
    try await client?.disconnect()
    NSLog("disconnect")

    // Immediately (try to) dealloc the client here. Some Combine subscribers
    // will not get a chance to respond to the disconnect, but that's fine since
    // we've already cleanly disconnected by now.
    client = nil
  }

  private func handleCommand(
    named command: String,
    arguments: [String]
  ) async throws {
    switch command {
    case "connect":
      guard let token = arguments.first else {
        appendToConsole(line: "[system] you need a user token, silly!")
        return
      }

      if client != nil {
        try await tearDownClient()
      }

      do {
        try await connect(authorizingWithToken: token)
      } catch {
        appendToConsole(line: "[system] failed to connect: \(error)")
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
    case "disconnect":
      try await tearDownClient()
      appendToConsole(line: "[system] disconnected!")
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

      Task {
        do {
          try await handleCommand(
            named: String(firstTokenWithoutSlash),
            arguments: tokens.dropFirst().map { String($0) }
          )
        } catch {
          appendToConsole(line: "[system] failed to handle command: \(error)")
        }
      }

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
