import AppKit

extension MessagesViewController: NSTableViewDelegate {
  func tableView(_: NSTableView, heightOfRow row: Int) -> CGFloat {
    let message = self.messages.elements[row].value
    return measureRowHeight(forMessage: message)
  }

  func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
    guard let view = tableView.makeView(withIdentifier: .unifiedMessageRow, owner: self) as? UnifiedMessageRow else {
      fatalError("failed to create view for row \(row)")
    }
    let (id, message) = self.messages.elements[row]

    var replyingToAbove = false
    if let reference = message.reference, row > 0 {
      let messageAbove = self.messages.elements[row - 1].value
      replyingToAbove = reference.messageID.id == messageAbove.id
    }

    view.configure(withMessage: message, isGroupHeader: self.messageIsFirstInSection(id: id), replyingToAbove: replyingToAbove)
    return view
  }

  func tableViewSelectionDidChange(_: Notification) {
    guard UserDefaults.standard.bool(forKey: "BSLKMessageRowHeightDebugging"),
          tableView.selectedRow > -1,
          let view = tableView.view(atColumn: 0, row: tableView.selectedRow, makeIfNecessary: false) as? UnifiedMessageRow
    else {
      return
    }

    let (messageID, message) = self.messages.elements[tableView.selectedRow]

    print(String(describing: message))

    let mismatching: String = cachedMessageHeights[messageID] != view.bounds.height ? " *** MISMATCH *** " : ""
    log.debug("*** Selected row #\(self.tableView.selectedRow, privacy: .public), message ID: \(messageID.string, privacy: .public)")
    let cachedHeight: String = cachedMessageHeights[messageID].map { String($0) } ?? "<not cached>"
    log.debug("    actual height = \(view.bounds.height, privacy: .public), cached = \(cachedHeight)\(mismatching)")
    log.debug("    content = \(self.messages[messageID]?.content ?? "<?>")")
  }
}
