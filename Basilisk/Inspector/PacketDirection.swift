import Foundation

/// The direction a packet can travel.
enum PacketDirection {
  /// Indicates a packet being received.
  case received

  /// Indicates a packet being sent.
  case sent

  /// A corresponding SF Symbol image name for the direction.
  var systemImageName: String {
    switch self {
    case .received: return "arrow.down"
    case .sent: return "arrow.up"
    }
  }
}
