public enum WebSocketState {
  /// The websocket is currently working to establish a connection.
  case connecting

  /// The websocket has established a connection.
  case connected

  /// The websocket has encountered a failure that has resulted in a
  /// disconnection.
  case failed

  /// The websocket has been disconnected.
  ///
  /// The disconnection may or may not have been caused by an error.
  case disconnected

  /// The websocket connection has become unviable. It may be restored to
  /// ``connected`` in the future, or it may become ``failed`` or ``disconnected``.
  case unviable
}
