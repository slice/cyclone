import Foundation
import os

/// A structure that handles incoming Discord gateway packets for a ``Client``.
class GatewayHandler {
  unowned var client: Client
  private var log: Logger

  init(client: Client) {
    self.client = client
    self.log = Logger(subsystem: "zone.slice.Contempt", category: "ingestion")
  }

  private func handleDispatchPacket(_: GatewayPacket<Any>) {}

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
      self.client.sequence = sequence
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
      self.log.info("HELLO")
      self.log.info("beginning to <3beat (interval: \(heartbeatInterval)ms)")
      self.client.beginHeartbeating(every: .milliseconds(heartbeatInterval))
      self.log.info("IDENTIFYing...")
      self.client.identify()
    case .heartbeat:
      self.client.heartbeat()
    default:
      break
    }
  }
}
