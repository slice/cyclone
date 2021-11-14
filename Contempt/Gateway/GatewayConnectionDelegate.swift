import Foundation

public protocol GatewayConnectionDelegate {
  /// Tells the delegate that we have received a `HELLO` packet from the gateway.
  func gatewaySentHello(heartbeatInterval: TimeInterval)

  /// Tells the delegate that we have received a packet from the gateway.
  func gatewaySentPacket(_ packet: GatewayPacket<Any>)
}
