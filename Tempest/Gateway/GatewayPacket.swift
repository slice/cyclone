import Foundation
import SwiftyJSON

/// A single packet from the Discord gateway.
public struct GatewayPacket<EventData: Decodable> {
  /// The opcode for this packet (`HELLO`, `HEARTBEAT`, etc.)
  public let op: Opcode

  /// The event data for this packet.
  public let eventData: EventData?

  /// The sequence number for this packet. Only present for `DISPATCH` packets.
  public let sequence: Double?

  /// The event name for this packet. Only present for `DISPATCH` packets.
  public let eventName: String?

  public init(op: Opcode, eventData: EventData?, sequence: Double?, eventName: String?) {
    self.op = op
    self.eventData = eventData
    self.sequence = sequence
    self.eventName = eventName
  }
}

extension GatewayPacket: Decodable {
  enum CodingKeys: String, CodingKey {
    case op
    case eventData = "d"
    case sequence = "s"
    case eventName = "t"
  }
}
