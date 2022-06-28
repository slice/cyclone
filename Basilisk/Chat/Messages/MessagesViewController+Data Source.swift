extension MessagesViewController {
  func setupDataSource() {
    dataSource =
      MessagesDiffableDataSource(tableView: tableView) { [unowned self] tableView, tableColumn, row, snowflake in
        let item = tableView.makeView(withIdentifier: .unifiedMessageRow, owner: nil) as! UnifiedMessageRow

        guard let message = self.messages[snowflake] else {
          self.log.warning("tried to make item for message not present in state")
          return .init(frame: .zero)
        }

        item.configure(withMessage: message, isGroupHeader: messageIsFirstInSection(id: message.id))
        return item
      }

    tableView.dataSource = dataSource
  }
}
