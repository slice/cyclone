import Combine

/// A store for logged messages.
class LogStore {
  /// The logged gateway messages.
  var messages: [LogMessage] = []

  /// A Combine subject for incoming log messages.
  var newMessages = PassthroughSubject<LogMessage, Never>()

  init(messages: [LogMessage]) {
    self.messages = messages
  }

  convenience init() {
    self.init(messages: [])
  }

  /// Clear all messages from the log store.
  @MainActor func clear() {
    messages.removeAll()
  }

  /// Append a new message to the log store.
  @MainActor func appendMessage(_ message: LogMessage) {
    messages.append(message)
    newMessages.send(message)
  }
}
