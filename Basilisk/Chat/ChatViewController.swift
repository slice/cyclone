import Cocoa
import Combine
import Contempt
import FineJSON
import GenericJSON
import RichJSONParser

@MainActor class ChatViewController: NSSplitViewController {
  var navigatorViewController: NavigatorViewController {
    splitViewItems[0].viewController as! NavigatorViewController
  }

  var messagesViewController: MessagesViewController {
    splitViewItems[1].viewController as! MessagesViewController
  }

  var client: Client?
  var focusedChannelID: UInt64?
  var gatewayPacketHandler: Task<Void, Never>?
  var gatewayGuildsSink: AnyCancellable!
  var gatewayUserSettingsSink: AnyCancellable!
  var selectedGuildID: Guild.ID?
  var exhaustedMessageHistory = false
  var requestingMoreHistory = false

  var selectedGuild: Guild? {
    client?.guilds.first { $0.id == selectedGuildID }
  }

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

    splitViewItems[1].titlebarSeparatorStyle = .shadow

    navigatorViewController.delegate = self

    messagesViewController.onRunCommand = { [weak self] command, args in
      guard let self = self else { return }

      Task {
        do {
          try await self.handleCommand(named: command, arguments: args)
        } catch {
          self.messagesViewController
            .appendToConsole(
              line: "[system] failed to handle command: \(error)"
            )
        }
      }
    }
    messagesViewController.onSendMessage = { [weak self] content in
      if let self = self, let focusedChannelID = self.focusedChannelID,
         let client = self.client
      {
        let randomNumber = Int.random(in: 0 ... 1_000_000_000)
        let request = try! client.http.apiRequest(
          to: "/channels/\(focusedChannelID)/messages",
          method: .post,
          body: .object(.init([
            "content": .string(content),
            "tts": .boolean(false),
            "nonce": .string(String(randomNumber)),
          ]))
        )!
        Task { [request] in
          try! await client.http.request(request, withSpoofedHeadersFor: .xhr)
        }
      }
    }
    messagesViewController.onScrolledNearTop = { [weak self] in
      self?.requestedToLoadMoreHistory()
    }
  }

  func requestedToLoadMoreHistory() {
    guard !exhaustedMessageHistory else {
      NSLog("message history is exhausted, not loading more posts")
      return
    }

    guard let client = client, !requestingMoreHistory,
          let focusedChannelID = focusedChannelID
    else {
      return
    }

    NSLog("requesting more messages")
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
      let json = try! await client.http.requestParsingJSON(
        request,
        withSpoofedHeadersFor: .xhr
      )
      let messages = json.arrayValue!.map(Message.init(json:))
      self.messagesViewController.prependOldMessages(messages)

      if messages.count < limit {
        NSLog("received %@ messages, history is exhausted")
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
        guard let json = try? await client.http.requestParsingJSON(
          request,
          withSpoofedHeadersFor: .xhr
        ) else { return }
        let messages = json.arrayValue!.map(Message.init(json:))
        self.messagesViewController.applyInitialMessages(messages)
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
          let guildPositions = userSettings["guild_positions"]?.arrayValue?
          .compactMap(\.stringValue).map(Snowflake.init(string:)),
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
    try await client.http.requestLandingPage()
    client.connect()
    setUpGatewayPacketHandler()
    gatewayGuildsSink = client.guildsChanged.receive(on: RunLoop.main)
      .sink { [weak self] _ in
        self?.applyGuilds()
      }
    gatewayUserSettingsSink = client.userSettingsChanged
      .receive(on: RunLoop.main)
      .sink { [weak self] dictionary in
        guard dictionary["guild_positions"] != nil ||
          dictionary["guild_folders"] != nil, let self = self else { return }
        self.applyGuilds()
      }
  }

  private func applyGuilds() {
    guard let guilds = guildsSortedAccordingToUserSettings() else {
      return
    }

    navigatorViewController.reloadWithGuildIDs(guilds.map(\.id))
  }

  func logPacket(_ packet: GatewayPacket) {
    let logMessage = LogMessage(
      content: packet.rawPayload,
      gatewayPacket: packet,
      timestamp: Date.now,
      direction: .received
    )

    let delegate = NSApp.delegate as! AppDelegate
    delegate.gatewayLogStore.appendMessage(logMessage)
  }

  func setUpGatewayPacketHandler() {
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

  func handleGatewayPacket(_ packet: GatewayPacket) async {
    if let eventName = packet.eventName, eventName == "MESSAGE_CREATE" {
      let data = packet.eventData!.objectValue!

      let channelID = UInt64(data["channel_id"]!.stringValue!)
      guard channelID == focusedChannelID else { return }

      let message = Message(json: packet.eventData!)
      messagesViewController.appendNewlyReceivedMessage(message)
    }
  }

  /// Disconnect from the gateway and tear down the Discord client.
  func tearDownClient() async throws {
    NSLog("tearing down client")
    gatewayPacketHandler?.cancel()

    // Disconnect from the Discord gateway with a 1000 close code.
    do {
      try await client?.disconnect()
    } catch {
      NSLog(
        "failed to disconnect, dealloc-ing anyways: %@",
        error.localizedDescription
      )
    }
    NSLog("disconnect")

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
