import Contempt
import Foundation

/// A log message that is displayed in the gateway inspector.
struct LogMessage: Identifiable {
  /// The identifier of the message.
  let id = UUID()

  /// The gateway packet associated with this message.
  let gatewayPacket: AnyGatewayPacket?

  /// The timestamp at which the message occurred.
  let timestamp: Date

  /// Whether the gateway packet was received or sent.
  let direction: PacketDirection
}
