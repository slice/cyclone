import SwiftUI
import Serpent

class TypingBridge: ObservableObject {
  /// The users which are currently typing.
  @Published var users: [User] = []
}
