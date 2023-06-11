import Foundation
import Serpent

/// A log message that is displayed in the gateway inspector.
struct LogMessage: Identifiable {
  /// The identifier of the message.
  let id = UUID()

  /// The direction in which the corresponding network packet was transmitted.
  let direction: PacketDirection

  /// The timestamp at which the message occurred.
  let timestamp: Date

  /// The log itself.
  let variant: LogVariant
}

enum LogVariant {
  case gateway(AnyGatewayPacket)
  case http(HTTPLog)
}
