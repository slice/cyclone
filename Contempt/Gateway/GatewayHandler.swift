import Foundation
import os

/// A structure that handles incoming Discord gateway packets.
public class GatewayHandler {
  private var log: Logger

  /// The latest sequence number received from the gateway.
  private(set) var sequence: Int?

  public var delegate: GatewayHandlerDelegate?

  init() {
    self.log = Logger(subsystem: "zone.slice.Contempt", category: "ingestion")
  }

  private func handleDispatchPacket(_ packet: GatewayPacket<Any>) {
    self.delegate?.gatewaySentDispatchPacket(packet)
  }

  /// Handle a single packet encoded in JSON from the Discord gateway.
  func handlePacket(ofJSON packet: String) {
    let packetEncoded = packet.data(using: .utf8)!

    let decodedPacket = try! JSONSerialization
      .jsonObject(with: packetEncoded) as! [String: Any]

    let eventName = decodedPacket["t"] as? String
    let sequence = decodedPacket["s"] as? Int
    let data = decodedPacket["d"] as? [String: Any]
    let opcode = Opcode(rawValue: decodedPacket["op"] as! Int)!

    self.log
      .debug(
        "t:\(String(describing: eventName)), s:\(String(describing: sequence)), op:\(opcode.rawValue)"
      )

    if let sequence = sequence {
      self.sequence = sequence
      self.delegate?.gatewaySentNewSequenceNumber(sequence)
    }

    switch opcode {
    case .dispatch:
      let packet = GatewayPacket<Any>(
        op: opcode,
        data: data as Any,
        sequence: sequence,
        eventName: eventName
      )
      self.handleDispatchPacket(packet)
    case .hello:
      let heartbeatInterval = data?["heartbeat_interval"] as! Int
      self.delegate?
        .gatewaySentHello(heartbeatInterval: Double(heartbeatInterval) / 1000.0)
    case .heartbeat:
      self.delegate?.gatewayRequestedHeartbeat()
    default:
      break
    }
  }
}
