import Combine
import Foundation
import Network
import os.log

/// Returns whether an `NWError` should be sent as an error to the `events`
/// subject.
private func shouldSendError(_ error: NWError) -> Bool {
  switch error {
  case .posix(.ECANCELED):
    return false
  default:
    return true
  }
}

/// A WebSocket connection.
class WebSocket {
  /// The endpoint to connect to.
  private var endpoint: NWEndpoint

  private var endpointURL: URL

  /// The internal `NWConnection` of this WebSocket.
  var connection: NWConnection!

  private var additionalHeaders: [(String, String)]

  /// A subject for all WebSocket events.
  public private(set) var events = PassthroughSubject<WebSocketEvent, NWError>()

  /// A subject for higher-level WebSocket state change events.
  ///
  /// The information emitted by this subject is a synthesized, simpler form of
  /// WebSocket connection state change and viability update change events.
  /// Prefer this for the user interface, as it is simpler to reinterpret into
  /// things the user can understand.
  public private(set) var state = CurrentValueSubject<WebSocketState, Never>(.disconnected)

  private var hasConnectedInitially: Bool = false

  private var messageHandlingWorkItem: DispatchWorkItem?

  private let log = Logger(subsystem: "zone.slice.Serpent", category: "low-level-websocket")

  init(endpoint: URL, additionalHeaders: [(String, String)] = []) {
    self.endpointURL = endpoint
    self.endpoint = NWEndpoint.url(endpointURL)
    self.additionalHeaders = additionalHeaders
    setupConnection()
  }

  private func setupConnection() {
    let parameters: NWParameters = endpointURL.scheme == "wss" ? .tls : .tcp
    let websocketOptions = NWProtocolWebSocket.Options()
    websocketOptions.autoReplyPing = true
    websocketOptions.maximumMessageSize = 1024 * 1024 * 100
    websocketOptions.setAdditionalHeaders(additionalHeaders)
    parameters.defaultProtocolStack.applicationProtocols.insert(
      websocketOptions,
      at: 0
    )

    connection = NWConnection(to: self.endpoint, using: parameters)

    connection.pathUpdateHandler = { [weak self] path in
      self?.log.info("connection path updated to: \(String(describing: path))")
    }

    connection.viabilityUpdateHandler = { [weak self] viability in
      guard let self else { return }
      self.log.info("connection viability updated to: \(viability)")
      if viability {
        if self.hasConnectedInitially {
          // Network has become viable again.
          self.state.send(WebSocketState.connected)
        } else {
          // Network is becoming viable for the first time (happens after the
          // initial connection).
          self.hasConnectedInitially = true
        }
      } else {
        self.state.send(.unviable)
      }
    }

    connection.betterPathUpdateHandler = { [weak self] betterPath in
      self?.log.info("better path updated to: \(betterPath)")
    }

    connection.stateUpdateHandler = { [weak self] connectionState in
      guard let self else { return }
      self.log.info("connection state has changed to: \(String(describing: connectionState))")
      self.events.send(.connectionStateUpdate(connectionState))

      switch connectionState {
      case .ready:
        self.state.send(WebSocketState.connected)
      case .failed:
        self.state.send(.failed)
        self.log.error("ending events stream, state = failed")
        self.events.send(completion: .finished)
      case .setup, .preparing, .waiting:
        self.state.send(.connecting)
      case .cancelled:
        self.state.send(.disconnected)
        self.log.error("ending events stream, state = cancelled")
        self.events.send(completion: .finished)
      default:
        self.log.notice("cannot forward unknown websocket state: \(String(describing: connectionState))")
      }
    }
  }

  /// Recreates any Combine publishers, force cancels the connection, and
  /// initiates another connection.
  ///
  /// After you call this method, you must recreate your Combine sinks. Any
  /// existing Combine sinks will cease to work.
  ///
  /// It also seems that you must call `restart` on the ``connection`` after
  /// it becomes `ready` again. You should only do this after calling this
  /// method.
  func reconnect() {
    hasConnectedInitially = false
    setupConnection()
    events = .init()
    state = .init(.disconnected)
    connect()
  }

  /// Initiates the WebSocket connection on a `DispatchQueue`.
  func connect(onDispatchQueue queue: DispatchQueue = .main) {
    messageHandlingWorkItem?.cancel()
    connection.start(queue: queue)
    messageHandlingWorkItem = DispatchWorkItem(
      qos: .userInteractive,
      flags: [],
      block: handleMessage
    )
    queue.async(execute: messageHandlingWorkItem!)
  }

  private func handleMessage() {
    connection.receiveMessage { [weak self] data, context, _, error in
      guard let self else { return }

      if let error, shouldSendError(error) {
        self.log.error("errored while trying to recv: \(error)")
        return
      }

      guard let data,
            !data.isEmpty,
            let context,
            let firstMetadata = context.protocolMetadata.first as? NWProtocolWebSocket.Metadata
      else {
        return
      }

      if firstMetadata.opcode == .close {
        // WebSocket is about to go away with a certain close code.
        self.events
          .send(.isGoingToClose(closeCode: firstMetadata.closeCode,
                                reason: data))
        return
      }

      self.events.send(.message(data))

      // Handle another message.
      self.handleMessage()
    }
  }

  /// Send data through the WebSocket.
  private func send(
    data: Data,
    context: NWConnection.ContentContext
  ) async throws {
    // The Swift compiler can't infer the type of the continuation without this.
    // We could also just say `return` here, but swiftformat removes that since
    // it *should* be redundant here.
    let _: Void =
      try await withCheckedThrowingContinuation { [weak self] continuation in
        guard let self else { return }

        self.connection.send(
          content: data,
          contentContext: context,
          completion: .contentProcessed { error in
            if let error {
              continuation.resume(throwing: error)
              return
            }

            continuation.resume()
          }
        )
      }
  }

  /// Send text through the WebSocket.
  func send(text: String) async throws {
    let context = NWConnection.ContentContext(
      identifier: "textContext",
      metadata: [NWProtocolWebSocket.Metadata(opcode: .text)]
    )
    try await send(data: text.data(using: .utf8)!, context: context)
  }

  /// Sends binary data through the WebSocket.
  func send(data: Data) async throws {
    let context = NWConnection.ContentContext(
      identifier: "binaryContext",
      metadata: [NWProtocolWebSocket.Metadata(opcode: .binary)]
    )
    try await send(data: data, context: context)
  }

  /// Disconnects the WebSocket with a close code.
  func disconnect(withCloseCode closeCode: NWProtocolWebSocket
    .CloseCode = .protocolCode(.normalClosure)) async throws
  {
    let metadata = NWProtocolWebSocket.Metadata(opcode: .close)
    metadata.closeCode = closeCode
    let context = NWConnection.ContentContext(
      identifier: "context",
      metadata: [metadata]
    )

    messageHandlingWorkItem?.cancel()

    return try await withCheckedThrowingContinuation { [weak self] continuation in
      guard let connection = self?.connection else {
        continuation.resume()
        return
      }

      connection.send(
        content: nil,
        contentContext: context,
        completion: .contentProcessed { error in
          if let error, shouldSendError(error) {
            continuation.resume(throwing: error)
            return
          }

          connection.cancel()
          continuation.resume()
        }
      )
    }
  }
}
