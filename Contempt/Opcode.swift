/// Discord Gateway opcodes.
enum Opcode: Int {
  case dispatch = 0
  case heartbeat = 1
  case identify = 2
  case presenceUpdate = 3
  case voiceStateUpdate = 4
  case resume = 6
  case reconnect = 7
  case requestGuildMembers = 8
  case invalidSession = 9
  case hello = 10
  case heartbeatAck = 11
}
