import Foundation
import Contempt

actor Accounts {
  /// The array of saved accounts.
  static var accounts: [Account.ID: Account] = [:]

  /// The active Contempt `Client` objects for each account.
  static var clients: [Account: Client] = [:]

  static func dataDirectory() -> URL {
    let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return supportDirectory.appendingPathComponent("Basilisk")
  }

  static var defaultAccountsPath: URL {
    dataDirectory().appendingPathComponent("accounts.json")
  }

  static func save(to destination: URL = defaultAccountsPath) throws {
    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                            withIntermediateDirectories: true,
                                            attributes: nil)
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    try encoder.encode(Self.accounts).write(to: destination)
  }

  static func read(from file: URL = defaultAccountsPath) throws {
    let data = try Data(contentsOf: file)
    accounts = try JSONDecoder().decode([Account.ID: Account].self, from: data)
  }
}
