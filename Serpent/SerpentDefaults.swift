import Foundation

enum SerpentDefaults: String {
  /// Logs all received WebSocket messages. This can be quite noisy.
  case logReceivedWebSocketMessages = "SRPNLogReceivedWebSocketMessages"

  /// Dumps the `READY` and `READY_SUPPLEMENTAL` gateway packets to a temporary
  /// directory.
  case dumpReadyPackets = "SRPNDumpReadyPackets"
}
