import Kingfisher
import Serpent
import SwiftUI

struct TypingView: View {
  @ObservedObject var bridge: TypingBridge

  static let animation: Animation = .spring(response: 0.3, dampingFraction: 0.7)

  static func separator(offset: Int, total: Int) -> String {
    switch offset {
    case total - 2:
      total > 2 ? ", and " : " and "
    case total - 1:
      ""
    default:
      ", "
    }
  }

  var body: some View {
    HStack(spacing: 0.0) {
      let enumeratedUsers = Array(bridge.users.enumerated())
      let total = enumeratedUsers.count

      ForEach(enumeratedUsers, id: \.element.id) { pair in
        let separator = Self.separator(offset: pair.offset, total: total)

        HStack(spacing: 4.0) {
          AvatarView(asset: pair.element.avatar)
            .frame(width: 15, height: 15)

          HStack(spacing: 0) {
            Text(pair.element.username).fontWeight(.bold)
            Text(separator)
          }
          .layoutPriority(1)
        }
      }

      if total > 0 {
        Text(total == 1 ? " is typing…" : " are typing…")
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
