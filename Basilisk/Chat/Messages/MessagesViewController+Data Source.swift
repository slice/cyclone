extension MessagesViewController {
  func setupDataSource() {
    dataSource =
      MessagesDiffableDataSource(tableView: tableView) {
        [weak self] tableView, tableColumn, _, snowflake in
        guard let self = self else { return .init(frame: .zero) }

        let item = tableView.makeView(withIdentifier: .message, owner: nil) as! MessageRow

        guard let message = self.messages[snowflake] else {
          self.log.warning("tried to make item for message not present in state")
          return .init(frame: .zero)
        }

        item.configure(withMessage: message)
        if let superview = item.superview {
          let t = superview.trailingAnchor.constraint(equalTo: item.trailingAnchor)
          t.priority = .init(1000.0)
          t.isActive = true
        }
        return item
      }

    dataSource.sectionHeaderViewProvider = { [weak self] collectionView, row, section in
      guard let self = self else { return .init(frame: .zero) }

      let item =
        self.tableView.makeView(withIdentifier: .messageGroupHeader, owner: nil)
        as! MessageGroupHeader

      let message = self.messages[section.firstMessageID]!
      item.groupAuthorTextField.stringValue = message.author.username
      item.groupAvatarRounding.radius = 10.0
      if let avatar = message.author.avatar {
        item.groupAvatarImageView.kf.setImage(with: avatar.url(withFileExtension: "png"))
      }
      item.groupTimestampTextField.stringValue = message.id.timestamp.formatted(
        date: .omitted, time: .shortened)

      return item
    }

    tableView.dataSource = dataSource
  }
}
