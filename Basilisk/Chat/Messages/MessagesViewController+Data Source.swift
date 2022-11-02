import AppKit

extension MessagesViewController: NSTableViewDataSource {
  func numberOfRows(in _: NSTableView) -> Int {
    self.messages.count
  }

  func tableView(_: NSTableView, objectValueFor _: NSTableColumn?, row: Int) -> Any? {
    self.messages.elements[row].value
  }

  func setupDataSource() {
    tableView.dataSource = self
  }
}
