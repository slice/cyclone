import Kingfisher
import Serpent
import SwiftUI

struct AvatarView: View {
  var asset: Asset?

  var body: some View {
    Group {
      // TODO: Don't load the larger image if the size is small enough. Be smart
      // about it.
      if let avatarURL = asset?.url(withFileExtension: "png") {
        KFImage.url(avatarURL)
          .interpolation(.high)
          .antialiased(true)
          // TODO: This placeholder is inconsistent with the rest of the UI; it
          // should really be a loading spinner.
          .placeholder { _ in Color.secondary }
          .resizable()
      } else {
        Color.secondary
      }
    }
    .cornerRadius(5, antialiased: true)
  }
}

struct AvatarView_Previews: PreviewProvider {
  static var previews: some View {
    AvatarView(asset: Asset(avatarForUser: Ref<User>(id: 150750980097441792), hash: "5c1c7b1628436d841883e986ebbc7e6f"))
      .frame(width: 32, height: 32)
      .padding()
  }
}
