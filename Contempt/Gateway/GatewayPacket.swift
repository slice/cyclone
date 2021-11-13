import Foundation

/// A single packet from the Discord gateway.
public struct GatewayPacket<Data> {
  /// The opcode for this packet (`HELLO`, `HEARTBEAT`, etc.)
  public let op: Opcode

  /// The event data for this packet.
  public let data: Data

  /// The sequence number for this packet. Only present for `DISPATCH` packets.
  public let sequence: Int?

  /// The event name for this packet. Only present for `DISPATCH` packets.
  public let eventName: String?
}
