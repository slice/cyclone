import Foundation

public protocol ClientDelegate: AnyObject {
  /// Tells the delegate that the client received a dispatch packet from the
  /// Discord gateway.
  func clientReceivedDispatchPacket(_ packet: GatewayPacket<Any>)
}
