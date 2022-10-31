import SwiftUI
import Serpent
import Kingfisher

struct TypingView: View {
  @ObservedObject var bridge: TypingBridge

  static let animation: Animation = .spring(response: 0.3, dampingFraction: 0.7)

  static func separator(offset: Int, total: Int) -> String {
    switch offset {
    case total - 2:
      return total > 2 ? ", and " : " and "
    case total - 1:
      return ""
    default:
      return ", "
    }
  }

  var body: some View {
    HStack(spacing: 0.0) {
      let enumeratedUsers = Array(bridge.users.enumerated())
      let total = enumeratedUsers.count

      ForEach(enumeratedUsers, id: \.element.id) { pair in
        let separator = Self.separator(offset: pair.offset, total: total)

        HStack(spacing: 4.0) {
          Group {
            if let avatarURL = pair.element.avatar?.url(withFileExtension: "png") {
              // TODO: Don't load the full image here.
              KFImage.url(avatarURL)
                // TODO: This placeholder is inconsistent with the rest of the UI.
                .placeholder { _ in Color.secondary }
                .resizable()
            } else {
              Color.secondary
            }
          }
          .frame(width: 15.0, height: 15.0)
          .cornerRadius(5.0, antialiased: true)

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
