import Foundation

/// A single packet from the Discord gateway.
public struct GatewayPacket<Data> {
  /// The opcode for this packet (`HELLO`, `HEARTBEAT`, etc.)
  let op: Opcode

  /// The event data for this packet.
  let data: Data

  /// The sequence number for this packet. Only present for `DISPATCH` packets.
  let sequence: Int?

  /// The event name for this packet. Only present for `DISPATCH` packets.
  let eventName: String?
}
