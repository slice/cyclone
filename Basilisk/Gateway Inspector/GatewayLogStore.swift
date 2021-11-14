import Combine

/// A store for logged messages from the gateway.
class GatewayLogStore: ObservableObject {
  let objectWillChange = PassthroughSubject<Void, Never>()

  /// The logged gateway messages.
  var messages: [LogMessage] = []

  init(messages: [LogMessage]) {
    self.messages = messages
  }

  convenience init() {
    self.init(messages: [])
  }

  /// Append a new message to the log store.
  @MainActor func appendMessage(_ message: LogMessage) {
    messages.append(message)
    objectWillChange.send()
  }
}
