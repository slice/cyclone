import Network

public enum WebSocketEvent {
  /// A state update occurred.
  case connectionStateUpdate(NWConnection.State)

  /// A close frame was sent.
  case isGoingToClose(closeCode: NWProtocolWebSocket.CloseCode, reason: Data)

  /// A text or binary frame was sent.
  case message(Data)
}
