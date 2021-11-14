import Foundation

/// The direction a packet can travel.
enum PacketDirection {
  /// Indicates a packet being received from the gateway.
  case received

  /// Indicates a packet being sent to the gateway.
  case sent

  /// A corresponding SF Symbol image name for the direction.
  var systemImageName: String {
    switch self {
    case .received: return "arrow.down.circle"
    case .sent: return "paperplane"
    }
  }
}
