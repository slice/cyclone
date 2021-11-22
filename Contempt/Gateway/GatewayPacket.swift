import Foundation
import GenericJSON

/// A single packet from the Discord gateway.
public struct GatewayPacket {
  /// The opcode for this packet (`HELLO`, `HEARTBEAT`, etc.)
  public let op: Opcode

  /// The event data for this packet.
  public let eventData: JSON?

  /// The sequence number for this packet. Only present for `DISPATCH` packets.
  public let sequence: Double?

  /// The event name for this packet. Only present for `DISPATCH` packets.
  public let eventName: String?

  /// The raw payload received over the gateway that was deserialized into this
  /// packet.
  public let rawPayload: String
}
