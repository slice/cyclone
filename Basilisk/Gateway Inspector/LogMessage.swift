import Contempt
import Foundation

/// A log message that is displayed in the gateway inspector.
struct LogMessage: Identifiable {
  /// The identifier of the message.
  let id = UUID()

  /// The contents of the message.
  let content: String

  /// The gateway packet associated with this message.
  let gatewayPacket: GatewayPacket?

  /// The timestamp at which the message occurred.
  let timestamp: Date

  /// Whether the gateway packet was received or sent.
  let direction: PacketDirection

  /// A truncated-if-needed variant of the message contents.
  func truncatedContent(maximumLength: Int) -> String {
    guard content.count > maximumLength else { return content }
    return content[content.startIndex ..< content
      .index(content.startIndex, offsetBy: maximumLength)] + "\u{2026}"
  }
}
