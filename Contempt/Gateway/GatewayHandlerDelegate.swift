import Foundation

public protocol GatewayHandlerDelegate {
  /// Tells the delegate that the gateway requested a heartbeat.
  func gatewayRequestedHeartbeat()

  /// Tells the delegate that a new sequence number was received.
  func gatewaySentNewSequenceNumber(_ sequence: Int)

  /// Tells the delegate that we have received a `HELLO` packet from the gateway.
  func gatewaySentHello(heartbeatInterval: TimeInterval)

  /// Tells the delegate that we have received a `DISPATCH` packet from the gateway.
  func gatewaySentDispatchPacket(_ packet: GatewayPacket<Any>)
}
