import Tempest

class Session {
  /// The details of the account such as token and disguise.
  var account: Account

  /// The Tempest client associated with this account, which facilitates API
  /// and gateway interactions, along with reconnections and state tracking.
  var client: Client

  init(account: Account, client: Client) {
    self.account = account
    self.client = client
  }
}
