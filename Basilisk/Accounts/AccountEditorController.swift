import Cocoa

class AccountEditorController: NSViewController {
  @IBOutlet var nameField: NSTextField!
  @IBOutlet var tokenField: NSSecureTextField!
  @IBOutlet var baseURLField: NSTextField!
  @IBOutlet var gatewayURLField: NSTextField!

  var editingAccountID: Account.ID! {
    didSet {
      updateFields()
    }
  }

  var editingAccount: Account? {
    get {
      Accounts.accounts[editingAccountID]
    }

    set(account) {
      guard let account else { return }
      Accounts.accounts[editingAccountID] = account
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
  }

  func updateFields() {
    nameField.stringValue = editingAccount?.name ?? ""
    tokenField.stringValue = editingAccount?.token ?? ""
    baseURLField.stringValue = editingAccount?.baseURL.absoluteString ?? ""
    gatewayURLField.stringValue = editingAccount?.gatewayURL.absoluteString ?? ""
  }

  @IBAction func finishedEditing(_: Any) {
    editingAccount?.name = nameField.stringValue
    editingAccount?.token = tokenField.stringValue
    guard let newBaseURL = URL(string: baseURLField.stringValue) else {
      presentError(BasiliskError.invalidAccountValues)
      return
    }
    editingAccount?.baseURL = newBaseURL
    guard let newGatewayURL = URL(string: gatewayURLField.stringValue) else {
      presentError(BasiliskError.invalidAccountValues)
      return
    }
    editingAccount?.gatewayURL = newGatewayURL
    try! Accounts.save()
    if let accountsViewController = parent?.parent as? AccountsViewController {
      accountsViewController.applySnapshot()
      guard let rowIndex = accountsViewController.accountsDataSource.row(forItemIdentifier: editingAccountID) else { return }
      accountsViewController.accountsTableView.selectRowIndexes([rowIndex], byExtendingSelection: false)
    }
  }
}
