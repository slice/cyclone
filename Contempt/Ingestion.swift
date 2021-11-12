import Foundation
import os

/// Discord Gateway message ingestion apparatus.
class Ingestion {
  unowned var client: Client
  private var log: Logger

  init(client: Client) {
    self.client = client
    self.log = Logger(subsystem: "zone.slice.Contempt", category: "ingestion")
  }

  func handleEvent(event: String, payload _: [String: Any], data: Data) {
    let filename = "discord-\(Date.now.timeIntervalSince1970)-\(event)"
    try! data.write(to: URL(fileURLWithPath: "/var/tmp/\(filename).json"))
  }

  func handleGatewayMessage(text: String) {
    let data = text.data(using: .utf8)!
    let jsonObject = try! JSONSerialization.jsonObject(
      with: data,
      options: []
    ) as! [String: Any]

    let event = jsonObject["t"] as? String
    let sequence = jsonObject["s"] as? Int
    let payload = jsonObject["d"] as? [String: Any]
    let opcode = Opcode(rawValue: jsonObject["op"] as! Int)!

    self.log
      .debug(
        "t:\(String(describing: event)), s:\(String(describing: sequence)), op:\(opcode.rawValue)"
      )
    if let sequence = sequence {
      self.client.sequence = sequence
    }

    switch opcode {
    case .dispatch:
      // Dispatch
      self.handleEvent(event: event!, payload: payload!, data: data)
    case .hello:
      // Hello
      let heartbeatInterval = payload?["heartbeat_interval"] as! Int
      self.log.info("heartbeating (interval: \(heartbeatInterval)ms)")
      self.client.beginHeartbeating(interval: .milliseconds(heartbeatInterval))
      self.client.identify()
    default:
      break
    }
  }
}
