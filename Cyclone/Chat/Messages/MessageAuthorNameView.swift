import Tempest
import SwiftUI

struct MessageAuthorNameView: View {
  var authorName: String
  var referencedAuthorName: String?
  var referencedAvatar: Asset?
  var displayReferencedAvatar: Bool = true
  var replyingToThemselves: Bool = false
  var replyingToAbove: Bool = false

  var body: some View {
    let font: Font = .system(size: 14.0, weight: .medium)
    if let referencedAuthorName {
      HStack(spacing: 6) {
        let authorName = Text(authorName)

        let separator = Text(verbatim: replyingToThemselves ? "continued" : "replied to")
          .fontWeight(.regular)
          .foregroundColor(.secondary)

        Text("\(authorName) \(separator)")

        if !replyingToThemselves {
          if displayReferencedAvatar {
            AvatarView(asset: referencedAvatar)
              .frame(width: 20, height: 20)
          }
          Text(verbatim: referencedAuthorName)
        }

        if replyingToAbove {
          Image(systemName: "arrow.turn.right.up")
            .foregroundStyle(.secondary)
        }
      }
      .font(font)
    } else {
      Text(verbatim: authorName)
        .font(font)
    }
  }
}

struct MessageAuthorNameView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      MessageAuthorNameView(authorName: "skip")
        .padding()

      let avatar = Asset(avatarForUser: Ref<User>(id: 718_974_758_406_062_142), hash: "c2c1f4ade6b508e73bf65c4ae9d9501c")
      MessageAuthorNameView(authorName: "skip", referencedAuthorName: "ilya", referencedAvatar: avatar, replyingToAbove: true)
        .padding()
    }
  }
}
