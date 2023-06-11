import Serpent
import SwiftUI

struct MessageFieldAccessoriesView: View {
  var replyingToMessage: Message?

  var body: some View {
    Group {
      if let replyingToMessage {
        HStack(spacing: 5) {
          Image(systemName: "arrowshape.turn.up.left.circle.fill")
          Text("Replying to")
          AvatarView(asset: replyingToMessage.author.displayAvatar)
            .frame(width: 16, height: 16)
          Text(verbatim: replyingToMessage.author.username)
            .fontWeight(.medium)
          ReferencedMessagePreviewView(message: replyingToMessage, displayArrow: false)
        }
      } else {
        Text("nothin' here…")
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

struct MessageFieldAccessoriesView_Previews: PreviewProvider {
  static var previews: some View {
    let author = User(fakeWithName: "skippy", id: 1)
    let message = Message(id: 1, content: "howdy howdy", author: author)
    MessageFieldAccessoriesView(replyingToMessage: message)
  }
}
