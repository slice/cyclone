struct Permissions: OptionSet {
  let rawValue: Int

  // swiftformat:disable all
  static let createInstantInvite   = Permissions(rawValue: 1 << 0)
  static let kickMembers           = Permissions(rawValue: 1 << 1)
  static let banMembers            = Permissions(rawValue: 1 << 2)
  static let administrator         = Permissions(rawValue: 1 << 3)
  static let manageChannels        = Permissions(rawValue: 1 << 4)
  static let manageGuild           = Permissions(rawValue: 1 << 5)
  static let addReactions          = Permissions(rawValue: 1 << 6)
  static let viewAuditLog          = Permissions(rawValue: 1 << 7)
  static let prioritySpeaker       = Permissions(rawValue: 1 << 8)
  static let stream                = Permissions(rawValue: 1 << 9)
  static let readMessages          = Permissions(rawValue: 1 << 10)
  static let sendMessages          = Permissions(rawValue: 1 << 11)
  static let sendTTSMessages       = Permissions(rawValue: 1 << 12)
  static let manageMessages        = Permissions(rawValue: 1 << 13)
  static let embedLinks            = Permissions(rawValue: 1 << 14)
  static let attachFiles           = Permissions(rawValue: 1 << 15)
  static let readMessageHistory    = Permissions(rawValue: 1 << 16)
  static let mentionEveryone       = Permissions(rawValue: 1 << 17)
  static let externalEmoji         = Permissions(rawValue: 1 << 18)
  static let viewGuildInsights     = Permissions(rawValue: 1 << 19)
  static let connectToVoice        = Permissions(rawValue: 1 << 20)
  static let speakInVoice          = Permissions(rawValue: 1 << 21)
  static let muteMembers           = Permissions(rawValue: 1 << 22)
  static let deafenMembers         = Permissions(rawValue: 1 << 23)
  static let moveMembers           = Permissions(rawValue: 1 << 24)
  static let useVoiceActivation    = Permissions(rawValue: 1 << 25)
  static let changeNickname        = Permissions(rawValue: 1 << 26)
  static let manageNicknames       = Permissions(rawValue: 1 << 27)
  static let manageRoles           = Permissions(rawValue: 1 << 28)
  static let manageWebhooks        = Permissions(rawValue: 1 << 29)
  static let manageEmoji           = Permissions(rawValue: 1 << 30)
  static let useSlashCommands      = Permissions(rawValue: 1 << 31)
  static let requestToSpeak        = Permissions(rawValue: 1 << 32)
  static let manageEvents          = Permissions(rawValue: 1 << 33)
  static let manageThreads         = Permissions(rawValue: 1 << 34)
  static let createPublicThreads   = Permissions(rawValue: 1 << 35)
  static let createPrivateThreads  = Permissions(rawValue: 1 << 36)
  static let externalStickers      = Permissions(rawValue: 1 << 37)
  static let sendMessagesInThreads = Permissions(rawValue: 1 << 38)
  // swiftformat:enable all
}

extension Permissions: Decodable {
  public init(from decoder: Decoder) throws {
    self = Permissions(rawValue: try decoder.decodeSingleIntString())
  }
}

public enum PermissionOverwritesType: Int, Decodable {
  case role = 0
  case member = 1
}

public struct PermissionOverwrites: Decodable {
  let deny: Permissions
  let allow: Permissions
  let id: Snowflake
  let type: PermissionOverwritesType?
}

public extension [PermissionOverwrites] {
  func isChannelVisible(for userID: Snowflake?) -> Bool {
    !contains { $0.deny.contains(.readMessages) && $0.id == userID }
  }
}
