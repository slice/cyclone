import Tempest
import SwiftUI

class TypingBridge: ObservableObject {
  /// The users which are currently typing.
  @Published var users: [User] = []
}
