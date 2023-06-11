import SwiftyJSON
import Foundation

/// A gateway packet assumed to have any event data structure.
public struct AnyGatewayPacket {
  /// The entire gateway packet.
  public let packet: GatewayPacket<JSON>

  /// The raw data of the entire gateway packet.
  ///
  /// Useful for reparsing into a `GatewayPacket` with a known event data
  /// structure.
  public let raw: Data

  enum Error: Swift.Error {
    case missingEventData
  }

  /// Attempts to parse this gateway packet into one with a more specific event
  /// data payload, returning the event data.
  public func reparse<T: Decodable>() throws -> T {
    let decoder = SerpentJSONDecoder()
    guard let data = try (decoder.decode(GatewayPacket<T>.self, from: raw)).eventData else {
      throw Error.missingEventData
    }
    return data
  }

  public init(packet: GatewayPacket<JSON>, raw: Data) {
    self.packet = packet
    self.raw = raw
  }
}
