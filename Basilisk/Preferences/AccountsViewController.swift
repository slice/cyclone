import Cocoa

enum AccountsSection {
  case main
}

class AccountsViewController: NSViewController, NSTableViewDelegate {
  @IBOutlet var accountsTableView: NSTableView!
  @IBOutlet var boxView: NSBox!
  var accountsDataSource: NSTableViewDiffableDataSource<AccountsSection, Account.ID>!
  @IBOutlet var removeAccountButton: NSButton!

  override func viewDidLoad() {
    super.viewDidLoad()
    accountsDataSource = NSTableViewDiffableDataSource(tableView: accountsTableView) { tableView, tableColumn, row, identifier in
      guard let account = Accounts.accounts[identifier] else {
        fatalError("failed to find account when making view")
      }
      let cell = tableView.makeView(withIdentifier: .init(rawValue: "account"), owner: nil) as! NSTableCellView
      cell.textField!.stringValue = account.name
      return cell
    }
    accountsTableView.dataSource = accountsDataSource
    accountsTableView.delegate = self
  }

  override func viewDidAppear() {
    applySnapshot()
    updateDetailView()
    updateButtons()
  }

  @IBAction func finishedEditingAccountName(_ sender: NSTextField) {
    let cell = sender.superview as! NSTableCellView
    let row = accountsTableView.row(for: cell)
    guard let selectedAccountID = accountsDataSource.itemIdentifier(forRow: row) else { return }
    guard let newName = cell.textField?.stringValue else { return }
    Accounts.accounts[selectedAccountID]?.name = newName
    updateDetailView()
  }

  func updateButtons() {
    removeAccountButton.isEnabled = !accountsTableView.selectedRowIndexes.isEmpty
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    updateDetailView()
    updateButtons()
  }

  func updateDetailView() {
    let tabViewController = children.first as! NSTabViewController

    guard let selectedRow = accountsTableView.selectedRowIndexes.first else {
      tabViewController.tabView.selectTabViewItem(at: 1)
      return
    }

    let editorTabViewItem = tabViewController.tabViewItems[0]
    let editorVC = editorTabViewItem.viewController as! AccountEditorController
    guard let accountID = accountsDataSource.itemIdentifier(forRow: selectedRow) else { return }
    editorVC.editingAccountID = accountID
    tabViewController.tabView.selectTabViewItem(editorTabViewItem)
  }

  internal func applySnapshot() {
    var snapshot = NSDiffableDataSourceSnapshot<AccountsSection, Account.ID>()
    snapshot.appendSections([.main])
    snapshot.appendItems(Accounts.accounts.values.map(\.id))
    accountsDataSource.apply(snapshot, animatingDifferences: false)
  }

  @IBAction func addAccount(_ sender: Any) {
    let account = Account(
      name: "Account",
      token: "",
      gatewayURL: URL(string: "wss://gateway.discord.gg/?encoding=json&v=9")!,
      baseURL: URL(string: "https://canary.discord.com")!
    )

    Accounts.accounts[account.id] = account

    applySnapshot()
    updateDetailView()
    try! Accounts.save()

    accountsTableView.selectRowIndexes([accountsTableView.numberOfRows - 1], byExtendingSelection: false)
  }

  @IBAction func removeAccount(_ sender: Any) {
    guard let accountID = accountsDataSource.itemIdentifier(forRow: accountsTableView.selectedRow) else { return }
    Accounts.accounts.removeValue(forKey: accountID)

    applySnapshot()
    updateDetailView()
    try! Accounts.save()

    let lastRow = accountsTableView.numberOfRows - 1
    if lastRow >= 0 {
      accountsTableView.selectRowIndexes([lastRow], byExtendingSelection: false)
    }
  }
}
