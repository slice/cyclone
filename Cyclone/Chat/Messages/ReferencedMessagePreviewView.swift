import Tempest
import SwiftUI

struct ReferencedMessagePreviewView: View {
  let hasAttachment: Bool
  let displayArrow: Bool
  let content: String?
  let maximumContentLength: Int = 50

  init(message: Message, displayArrow: Bool = true) {
    self.hasAttachment = !message.attachments.isEmpty
    self.displayArrow = displayArrow
    self.content = message.content
  }

  init(content: String) {
    self.hasAttachment = true
    self.displayArrow = true
    self.content = content
  }

  var truncatedContent: String? {
    content.map { content in
      content.count > maximumContentLength ? content.prefix(maximumContentLength) + "…" : content
    }
  }

  var hasContent: Bool {
    (truncatedContent?.isEmpty).map { !$0 } ?? false
  }

  var body: some View {
    HStack(spacing: 5) {
      if displayArrow {
        Image(systemName: "arrowshape.turn.up.left.circle.fill")
          .imageScale(.large)
          .foregroundStyle(.secondary)
      }
      Group {
        if hasContent {
          Text(verbatim: truncatedContent!)
            .lineLimit(1)
        } else {
          Text("Attachment")
            .font(.body.italic())
        }
        if hasAttachment {
          Image(systemName: "paperclip")
        }
      }.foregroundStyle(.secondary)
    }
  }
}

struct ReferencedMessagePreviewView_Previews: PreviewProvider {
  static var previews: some View {
    let content = "why do they call it oven when you of in the cold food of out hot eat the food"
    ReferencedMessagePreviewView(content: content)
      .padding()
  }
}
