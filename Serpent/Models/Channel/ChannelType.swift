import Foundation

public enum ChannelType: Int, Codable {
  case text = 0
  case dm = 1
  case voice = 2
  case groupDM = 3
  case category = 4
  case news = 5
  case store = 6
  case newsThread = 10
  case publicThread = 11
  case privateThread = 12
  case stageVoice = 13
  case directory = 14
  case forum = 15
}
