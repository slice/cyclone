import Cocoa
import Combine
import Contempt
import FineJSON
import RichJSONParser

@MainActor class ChatViewController: NSViewController {
  @IBOutlet var consoleTextView: NSTextView!
  @IBOutlet var inputTextField: NSTextField!
  @IBOutlet var consoleScrollView: NSScrollView!
  @IBOutlet var guildsCollectionView: NSCollectionView!

  var client: Client?
  var focusedChannelID: UInt64?
  var gatewayPacketHandler: Task<Void, Never>?
  var gatewayGuildsSink: AnyCancellable!

  var guildsDataSource: NSCollectionViewDiffableDataSource<
    GuildsSection,
    Guild.ID
  >!

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

    guildsCollectionView.register(
      GuildsCollectionViewItem.self,
      forItemWithIdentifier: .guild
    )
    guildsDataSource = makeDiffableDataSource()
    guildsCollectionView.collectionViewLayout = makeCollectionViewLayout()
    guildsCollectionView.dataSource = guildsDataSource
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
    appendToConsole(
      line: "[system] connecting to canary with token (\(truncatedToken))"
    )

    let client = Client(branch: .canary, token: token)
    self.client = client
    try await client.http.requestLandingPage()
    client.connect()
    setUpGatewayPacketHandler()
    gatewayGuildsSink = client.guildsChanged.receive(on: RunLoop.main)
      .sink { [weak self] _ in
        guard let guilds = self?.guildsSortedAccordingToUserSettings()
        else { return }

        var snapshot = NSDiffableDataSourceSnapshot<GuildsSection, Guild.ID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(guilds.map(\.id), toSection: .main)
        self?.guildsDataSource.apply(snapshot, animatingDifferences: true)
      }
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
  }
}
