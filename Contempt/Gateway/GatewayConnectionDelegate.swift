import Foundation

public protocol GatewayConnectionDelegate {
  /// Tells the delegate that we have received a `HELLO` packet from the gateway.
  func gatewaySentHello(heartbeatInterval: TimeInterval)

  /// Tells the delegate that we have received a `DISPATCH` packet from the gateway.
  func gatewaySentDispatchPacket(_ packet: GatewayPacket<Any>)
}
