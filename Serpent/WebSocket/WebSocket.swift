import Combine
import Foundation
import Network

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

  /// The internal `NWConnection` of this WebSocket.
  private var connection: NWConnection

  /// A Combine subject for WebSocket events.
  public let events = PassthroughSubject<WebSocketEvent, NWError>()

  private var messageHandlingWorkItem: DispatchWorkItem?

  init(endpoint: URL, additionalHeaders: [(String, String)] = []) {
    self.endpoint = NWEndpoint.url(endpoint)
    let parameters: NWParameters = endpoint.scheme == "wss" ? .tls : .tcp
    let websocketOptions = NWProtocolWebSocket.Options()
    websocketOptions.autoReplyPing = true
    websocketOptions.maximumMessageSize = 1024 * 1024 * 100
    websocketOptions.setAdditionalHeaders(additionalHeaders)
    parameters.defaultProtocolStack.applicationProtocols.insert(
      websocketOptions,
      at: 0
    )
    connection = NWConnection(to: self.endpoint, using: parameters)
    connection.stateUpdateHandler = { [weak self] connectionState in
      self?.events.send(.connectionStateUpdate(connectionState))

      if connectionState == .cancelled {
        self?.events.send(completion: .finished)
      }
    }
  }

  /// Initiates the WebSocket connection on a `DispatchQueue`.
  func connect(onDisptachQueue queue: DispatchQueue = .main) {
    connection.start(queue: queue)
    messageHandlingWorkItem?.cancel()
    messageHandlingWorkItem = DispatchWorkItem(
      qos: .userInteractive,
      flags: [],
      block: handleMessage
    )
    queue.async(execute: messageHandlingWorkItem!)
  }

  private func handleMessage() {
    connection.receiveMessage { [weak self] data, context, _, error in
      guard let self = self else { return }

      if let error = error, shouldSendError(error) {
        self.events.send(completion: .failure(error))
        return
      }

      guard let data = data, !data.isEmpty, let context = context,
            let firstMetadata = context.protocolMetadata
            .first as? NWProtocolWebSocket.Metadata
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
        guard let self = self else { return }

        self.connection.send(
          content: data,
          contentContext: context,
          completion: .contentProcessed { error in
            if let error = error {
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
          if let error = error, shouldSendError(error) {
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
