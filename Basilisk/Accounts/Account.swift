import Foundation

struct Account: Hashable, Codable, Identifiable {
  /// The account ID.
  var id: UUID = UUID()

  /// A human-friendly name for this account.
  var name: String

  /// The Discord account's token.
  var token: String

  /// The Discord gateway URL to connect to.
  var gatewayURL: URL

  /// The base Discord API to connect to.
  var baseURL: URL
}
