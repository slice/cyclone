import Foundation

struct Account: Hashable, Codable, Identifiable {
  /// The account ID.
  var id: UUID = .init()

  /// A human-friendly name for this account.
  var name: String

  /// The Discord account's token.
  var token: String

  /// The Discord gateway URL to connect to.
  var gatewayURL: URL

  /// The base Discord API to use when making HTTP requests.
  var baseURL: URL
}
