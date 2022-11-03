import Cocoa

// https://danieltull.co.uk/blog/2019/10/09/type-safe-user-defaults/
// https://mikeash.com/pyblog/friday-qa-2017-10-06-type-safe-user-defaults.html

public struct DefaultsKey<Value> {
  let key: String

  public init(_ key: String) {
    self.key = key
  }
}

extension DefaultsKey<Bool> {
  /// Loads a set of sample messages whenever a chat window is opened.
  static let loadSampleMessages = Self("BSLKLoadSampleMessages")

  /// Enables debugging facilities for message row heights.
  static let messageRowHeightDebugging = Self("BSLKMessageRowHeightDebugging")

  /// Automatically log in with the first account.
  static let automaticallyLogInWithFirstAccount = Self("BSLKAutomaticallyAuthorizeWithFirstAccount")

  /// Skips setup of message accessories (attachments, etc.)
  static let ignoreMessageAccessories = Self("BSLKIgnoreMessageAccessories")
}

enum BasiliskDefaults {
  public static func bool(_ key: DefaultsKey<Bool>) -> Bool {
    UserDefaults.standard.bool(forKey: key.key)
  }

  public static subscript<Value>(key: DefaultsKey<Value>) -> Value? {
    get {
      UserDefaults.standard.value(forKey: key.key) as? Value
    }

    set {
      UserDefaults.standard.set(newValue, forKey: key.key)
    }
  }
}
