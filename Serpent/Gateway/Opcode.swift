/// Discord gateway opcodes.
public enum Opcode: Int, Codable {
  // Last updated: 2022-08-24

  case dispatch = 0
  case heartbeat = 1
  case identify = 2
  case presenceUpdate = 3
  case voiceStateUpdate = 4
  case voiceServerPing = 5
  case resume = 6
  case reconnect = 7
  case requestGuildMembers = 8
  case invalidSession = 9
  case hello = 10
  case heartbeatAck = 11
  case guildSync = 12
  case callConnect = 13
  case guildSubscriptions = 14
  case lobbyConnect = 15
  case lobbyDisconnect = 16
  case lobbyVoiceStatesUpdate = 17
  case streamCreate = 18
  case streamDelete = 19
  case streamWatch = 20
  case streamPing = 21
  case streamSetPaused = 22
  case lfgSubscriptions 23
  case requestGuildApplicationCommands = 24
  case embeddedActivityLaunch = 25
  case embeddedActivityClose = 26
  case embeddedActivityUpdate = 27
  case requestForumUnreads = 28
  case remoteCommand = 29
}
