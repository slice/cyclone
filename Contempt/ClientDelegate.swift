import Foundation

public protocol ClientDelegate: AnyObject {
  /// Tells the delegate that the client received a packet from the Discord
  /// gateway.
  func clientReceivedGatewayPacket(_ packet: GatewayPacket<Any>)
}
