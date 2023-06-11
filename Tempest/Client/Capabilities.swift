/// Client capability flags.
///
/// A bitset used to declare to the Discord gateway what features the client
/// supports.
///
/// See: https://gist.github.com/dolfies/a8c27cdd1c77fb8b45313197fed5540a
struct Capabilities: OptionSet, Codable {
  let rawValue: UInt32

  static let noNotesInReady = Self(rawValue: 1 << 0)
  static let versionedReadStates = Self(rawValue: 1 << 2)
  static let versionedUserGuildSettings = Self(rawValue: 1 << 3)
  static let dehydratedReady = Self(rawValue: 1 << 4)
  static let readySupplemental = Self(rawValue: 1 << 5)
  static let guildExperimentPopulation = Self(rawValue: 1 << 6)
  static let enhancedReadStates = Self(rawValue: 1 << 7)
  static let authTokenSupport = Self(rawValue: 1 << 8)
  static let removeOldUserSettings = Self(rawValue: 1 << 9)
  static let clientCachingV2 = Self(rawValue: 1 << 10)
}
