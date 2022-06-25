import Cocoa
import Combine
import Serpent
import SwiftyJSON
import os.log

final class ChatViewController: NSSplitViewController {
  var navigatorViewController: NavigatorViewController {
    splitViewItems[0].viewController as! NavigatorViewController
  }

  var statusBarController: StatusBarContainerController {
    (splitViewItems[1].viewController as! StatusBarContainerController)
  }

  var messagesViewController: MessagesViewController {
    statusBarController.containedViewController as! MessagesViewController
  }

  var client: Client?
  var focusedChannelID: UInt64?
  var gatewayPacketHandler: Task<Void, Never>?

  var gatewayGuildsSink: AnyCancellable!
  var gatewayUserSettingsSink: AnyCancellable!
  var gatewaySentPacketsSink: AnyCancellable!
  var httpLoggingSink: AnyCancellable!
  var socketEventSink: AnyCancellable!
  var reconnectionSink: AnyCancellable!

  var selectedGuildID: Guild.ID?
  var exhaustedMessageHistory = false
  var requestingMoreHistory = false

  var selectedGuild: Guild? {
    client?.guilds.first { $0.id == selectedGuildID }
  }

  let log = Logger(subsystem: "zone.slice.Basilisk", category: "chat-view-controller")

  deinit {
    NSLog("ChatViewController deinit")

    // TODO(skip): The fact that disconnection happens asynchronously isn't
    // ideal, because it means that we can't guarantee a disconnect before
    // deinitializing. Is there a way to get around this?
    Task {
      try! await tearDownClient()
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    splitViewItems[1].titlebarSeparatorStyle = .shadow

    navigatorViewController.delegate = self
    messagesViewController.delegate = self
  }

  func requestedToLoadMoreHistory() {
    guard !exhaustedMessageHistory else {
      log.info("message history is exhausted, not loading more posts")
      return
    }

    guard let client = client, !requestingMoreHistory,
          let focusedChannelID = focusedChannelID
    else {
      return
    }

    log.debug("requesting more messages")
    requestingMoreHistory = true
    let limit = 50

    let request = try! client.http.apiRequest(
      to: "/channels/\(focusedChannelID)/messages",
      query: [
        "limit": String(limit),
        "before": String(messagesViewController.oldestMessageID!.uint64),
      ]
    )!

    Task { [request] in
      let messages: [Message] = try! await client.http.requestDecoding(
        request,
        withSpoofedHeadersFor: .xhr
      )

      self.messagesViewController.prependOldMessages(messages)

      if messages.count < limit {
        log.notice("received \(messages.count) messages (limit: \(limit)), history is exhausted")
        exhaustedMessageHistory = true
      }

      requestingMoreHistory = false
    }
  }

  func selectChannel(withID id: Snowflake) {
    focusedChannelID = id.uint64
    exhaustedMessageHistory = false

    if let client = client,
       let selectedGuild = selectedGuild,
       let channelName = selectedGuild.channels.first(where: { $0.id == id })?
       .name
    {
      view.window?.title = selectedGuild.name
      view.window?.subtitle = "#\(channelName)"
      let request = try! client.http.apiRequest(
        to: "/channels/\(id.uint64)/messages",
        query: ["limit": "50"]
      )!

      Task { [request] in
        do {
          let messages: [Message] = try await client.http.requestDecoding(request, withSpoofedHeadersFor: .xhr)
          self.messagesViewController.applyInitialMessages(messages)
        } catch {
          log.error("failed to fetch messages: \(String(describing: error), privacy: .public)")
          self.messagesViewController.applyInitialMessages([])
        }
      }
    }
  }

  func handleCommand(
    named command: String,
    arguments: [String]
  ) async throws {
    let say = { message in
      self.messagesViewController.appendToConsole(line: message)
    }

    switch command {
    case "connect":
      guard let token = arguments.first else {
        say("[system] you need a user token, silly!")
        return
      }

      if client != nil {
        try await tearDownClient()
      }

      do {
        try await connect(authorizingWithToken: token)
      } catch {
        say("[system] failed to connect: \(error)")
      }
    case "focus":
      guard let channelIDString = arguments.first,
            let channelID = UInt64(channelIDString)
      else {
        say("[system] provide a channel id... maybe...")
        return
      }

      focusedChannelID = channelID
      say("[system] focusing into <#\(channelID)>")
    case "disconnect":
      try await tearDownClient()
      say("[system] disconnected!")
    default:
      say("[system] dunno what \"\(command)\" is!")
    }
  }

  /// Returns a list of the client's `Guild`s, sorted according to the user's
  /// settings.
  func guildsSortedAccordingToUserSettings() -> [Guild]? {
    guard let userSettings = client?.userSettings,
          let guildPositions = userSettings["guild_positions"].array?.compactMap(\.string).map(Snowflake.init(string:)),
          let guilds = client?.guilds
    else { return client?.guilds }

    return guilds.sorted { thisGuild, thatGuild in
      let thisIndex = guildPositions.firstIndex(of: thisGuild.id) ?? 0
      let thatIndex = guildPositions.firstIndex(of: thatGuild.id) ?? 0
      return thisIndex < thatIndex
    }
  }

  func connect(authorizingWithToken token: String) async throws {
    let truncatedToken =
      "\(token[token.startIndex ..< token.index(token.startIndex, offsetBy: 5)])..."

    messagesViewController.appendToConsole(
      line: "[system] connecting to canary with token (\(truncatedToken))"
    )

    let client = Client(branch: .canary, token: token)
    self.client = client

    httpLoggingSink = client.http.subject.receive(on: RunLoop.main)
      .sink { log in
        let message = LogMessage(direction: .sent, timestamp: Date.now, variant: .http(log))
        (NSApp.delegate as! AppDelegate).gatewayLogStore.appendMessage(message)
      }

    try await client.http.requestLandingPage()
    client.connect()

    // TODO(skip): Probably just use a damn delegate for this.
    setUpGatewayPacketHandler()
    setupConnectionStateSink()

    reconnectionSink = client.gatewayConnection.reconnects.receive(on: RunLoop.main)
      .sink { [weak self] _ in
        // The websocket connection has been reset, so we need to reset our sink
        // too.
        self?.setupConnectionStateSink()
      }

    gatewayGuildsSink = client.guildsChanged.receive(on: RunLoop.main)
      .sink { [weak self] _ in
        self?.applyGuilds()
      }

    func bodyToString(_ body: Data?) -> String {
      guard let body = body else {
        return "<no body>"
      }

      return String(data: body, encoding: .utf8) ?? "<failed to decode body>"
    }

    gatewaySentPacketsSink = client.gatewayConnection.sentPackets.receive(on: RunLoop.main)
      .sink { (json, string) in
        let data = string.data(using: .utf8)!

        let packet = try! JSONDecoder().decode(GatewayPacket<JSON>.self, from: data)
        let anyPacket = AnyGatewayPacket(packet: packet, raw: data)

        let logMessage = LogMessage(
          direction: .sent,
          timestamp: Date.now,
          variant: .gateway(anyPacket)
        )

        (NSApp.delegate as! AppDelegate).gatewayLogStore.appendMessage(logMessage)
      }

    gatewayUserSettingsSink = client.userSettingsChanged
      .receive(on: RunLoop.main)
      .sink { [weak self] json in
        guard json["guild_positions"].exists() ||
          json["guild_folders"].exists(), let self = self else { return }
        self.applyGuilds()
      }
  }

  private func setupConnectionStateSink() {
    socketEventSink = client!.gatewayConnection.connectionState!.receive(on: RunLoop.main)
      .sink { [weak self] state in
        let connectionStatus: ConnectionStatus
        let connectionLabel: String

        switch state {
        case .connecting:
          connectionStatus = .connecting
          connectionLabel = "Connecting to Discord…"
        case .failed:
          connectionStatus = .disconnected
          connectionLabel = "Connection failed!"
        case .disconnected:
          connectionStatus = .disconnected
          connectionLabel = "Disconnected!"
        case .connected:
          connectionStatus = .connected
          connectionLabel = "Connected."
        case .unviable:
          connectionStatus = .connecting
          connectionLabel = "Network connection has become unviable…"
        }

        self?.statusBarController.connectionStatus.connectionStatus = connectionStatus
        self?.statusBarController.connectionStatusLabel.stringValue = connectionLabel
      }
  }

  private func applyGuilds() {
    guard let guilds = guildsSortedAccordingToUserSettings() else {
      return
    }

    navigatorViewController.reloadWithGuildIDs(guilds.map(\.id))
  }

  func logPacket(_ packet: AnyGatewayPacket) {
    let logMessage = LogMessage(
      direction: .received,
      timestamp: Date.now,
      variant: .gateway(packet)
    )

    let delegate = NSApp.delegate as! AppDelegate
    delegate.gatewayLogStore.appendMessage(logMessage)
  }

  func setUpGatewayPacketHandler() {
    guard let client = client else { return }

    gatewayPacketHandler = Task.detached(priority: .high) {
      for await packet in client.gatewayConnection.receivedPackets.bufferInfinitely()
        .values
      {
        await self.logPacket(packet)
        await self.handleGatewayPacket(packet)
      }
    }
  }

  func handleGatewayPacket(_ packet: AnyGatewayPacket) async {
    if let eventName = packet.packet.eventName, eventName == "MESSAGE_CREATE" {
      let data = packet.packet.eventData!

      let channelID = UInt64(data["channel_id"].string!)
      guard channelID == focusedChannelID else { return }

      let message: Message = try! packet.reparse()
      messagesViewController.appendNewlyReceivedMessage(message)
    }
  }

  /// Disconnect from the gateway and tear down the Discord client.
  func tearDownClient() async throws {
    log.notice("tearing down client")
    gatewayPacketHandler?.cancel()

    // Disconnect from the Discord gateway with a 1000 close code.
    do {
      try await client?.disconnect()
    } catch {
      log.error("failed to disconnect, dealloc-ing anyways: \(error)")
    }
    log.info("disconnected")

    // Immediately (try to) dealloc the client here. Some Combine subscribers
    // will not get a chance to respond to the disconnect, but that's fine since
    // we've already cleanly disconnected by now.
    client = nil

    focusedChannelID = nil
    selectedGuildID = nil
    navigatorViewController.reloadWithGuildIDs([])
    messagesViewController.applyInitialMessages([])
    view.window?.title = "Basilisk"
    view.window?.subtitle = ""
  }
}

extension ChatViewController: MessagesViewControllerDelegate {
  func messagesController(_ messagesController: MessagesViewController, commandInvoked command: String, arguments: [String]) {
    Task {
      do {
        try await handleCommand(named: command, arguments: arguments)
      } catch {
        log.error("failed to handle command: \(error, privacy: .public)")
        self.messagesViewController
          .appendToConsole(
            line: "[system] failed to handle command: \(error)"
          )
      }
    }
  }

  func messagesController(_ messagesController: MessagesViewController, messageSent message: String) {
    guard let focusedChannelID = self.focusedChannelID, let client = self.client else {
      return
    }

    Task {
      do {
        let request = try client.http.apiRequest(
          to: "/channels/\(focusedChannelID)/messages",
          method: .post,
          body: [
            "content": message,
            "tts": false,
            "nonce": String(Int.random(in: 0...1_000_000_000))
          ]
        )!
        let _ = try await client.http.request(request, withSpoofedHeadersFor: .xhr)
      } catch {
        log.error("failed to send message: \(error, privacy: .public)")
        messagesViewController.appendToConsole(line: "[system] failed to send message: \(error)")
      }
    }
  }

  func messagesControllerDidScrollNearTop(_ messagesController: MessagesViewController) {
    requestedToLoadMoreHistory()
  }
}

extension ChatViewController: NavigatorViewControllerDelegate {
  func navigatorViewController(_ navigatorViewController: NavigatorViewController,
                               didSelectChannelWithID channelID: Channel.ID,
                               inGuildWithID guildID: Guild.ID) {
    selectedGuildID = guildID
    selectChannel(withID: channelID)
  }

  func navigatorViewController(_ navigatorViewController: NavigatorViewController,
                               requestingGuildWithID id: Guild.ID
  ) -> Guild {
    guard let guild = client?.guilds.first(where: { $0.id == id }) else {
      fatalError("navigator requested client when we don't have one")
    }

    return guild
  }

  func navigatorViewController(_ navigatorViewController: NavigatorViewController,
                               didRequestCurrentUserID _: Void
  ) -> Snowflake? {
    client?.currentUser?.id
  }
}
