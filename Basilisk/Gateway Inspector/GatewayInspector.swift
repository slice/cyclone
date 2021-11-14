import Combine
import SwiftUI

struct GatewayInspector: View {
  @ObservedObject var state: GatewayLogStore
  @State private var selection = Set<LogMessage.ID>()

  private var selectedMessages: [LogMessage] {
    state.messages.filter { selection.contains($0.id) }
  }

  private var firstSelectedMessage: LogMessage? {
    selectedMessages.first
  }

  var body: some View {
    VSplitView {
      Table(state.messages, selection: $selection) {
        TableColumn("Timestamp") { message in
          Text(verbatim: message.timestamp
            .formatted(date: .omitted, time: .standard))
        }
        .width(80)

        TableColumn("Type") { message in
          HStack {
            Spacer()
            Image(systemName: message.direction.systemImageName)
            Spacer()
          }
        }
        .width(30)

        TableColumn("Packet") { message in
          Text(verbatim: message.truncatedContent)
            .font(.system(.body, design: .monospaced))
        }
      }
      .frame(minWidth: 700, minHeight: 300)

      Group {
        if selection.isEmpty {
          Text("(nothing selected)")
            .foregroundStyle(.secondary)
        } else if selection.count > 1 {
          Text("(multiple messages selected)")
            .foregroundStyle(.secondary)
        } else {
          ScrollableMonospaceTextView(text: firstSelectedMessage!.content)
        }
      }
      .frame(minHeight: 200, alignment: .center)
    }
    .navigationTitle("Gateway Inspector")
    .navigationSubtitle("messages")
  }
}

struct GatewayInspector_Previews: PreviewProvider {
  private static let sampleMessages: [LogMessage] = [
    LogMessage(
      content: "a sent message",
      timestamp: Date.now,
      direction: .sent
    ),
    LogMessage(
      content: "a received message",
      timestamp: Date.now + 1,
      direction: .received
    ),
    LogMessage(
      content: "another received message",
      timestamp: Date.now + 2,
      direction: .received
    ),
    LogMessage(
      content: "another sent message",
      timestamp: Date.now + 3,
      direction: .sent
    ),
    LogMessage(
      content: String(repeating: "a really long message ", count: 2000),
      timestamp: Date.now + 20,
      direction: .sent
    ),
  ]

  static var previews: some View {
    GatewayInspector(state: GatewayLogStore(messages: sampleMessages))
      .frame(width: 700, height: 500)
  }
}
