import Cocoa

// https://danieltull.co.uk/blog/2019/10/09/type-safe-user-defaults/
// https://mikeash.com/pyblog/friday-qa-2017-10-06-type-safe-user-defaults.html

public struct DefaultsKey<Value> {
  let key: String
  let defaultValue: Value

  public init(_ key: String, defaultValue: Value) {
    self.key = key
    self.defaultValue = defaultValue
  }
}

extension DefaultsKey<Bool> {
  /// Loads a set of sample messages whenever a chat window is opened.
  static let loadSampleMessages = Self("BSLKLoadSampleMessages", defaultValue: false)

  /// Enables debugging facilities for message row heights.
  static let messageRowHeightDebugging = Self("BSLKMessageRowHeightDebugging", defaultValue: false)

  /// Automatically log in with the first account.
  static let automaticallyLogInWithFirstAccount = Self("BSLKAutomaticallyAuthorizeWithFirstAccount", defaultValue: false)

  /// Skips setup of message accessories (attachments, etc.)
  static let ignoreMessageAccessories = Self("BSLKIgnoreMessageAccessories", defaultValue: false)

  /// Whether to interpret key events for quick selection.
  static let quickSelectEnabled = Self("BSLKQuickSelectEnabled", defaultValue: true)

  /// Whether to play a sound when moving the quick select outline or not.
  static let quickSelectPlaysSound = Self("BSLKQuickSelectPlaysSound", defaultValue: true)
}

extension DefaultsKey<Double> {
  /// How long it takes for the quick select outline floater to animate to its
  /// final position.
  static let quickSelectOutlineFloaterAnimationDuration = Self("BSLKQuickSelectOutlineFloaterAnimationDuration", defaultValue: 0.1)

  /// The volume of the quick select move sound.
  static let quickSelectSoundVolume = Self("BSLKQuickSelectSoundVolume", defaultValue: 0.7)

  /// How long it takes for the message field accessories to animate open or
  /// closed.
  static let messageFieldAccessoriesAnimationDuration = Self("BSLKMessageFieldAccessoriesAnimationDuration", defaultValue: 0.1)
}

enum BasiliskDefaults {
  public static func bool(_ key: DefaultsKey<Bool>) -> Bool {
    UserDefaults.standard.bool(forKey: key.key)
  }

  public static subscript<Value>(key: DefaultsKey<Value>) -> Value {
    get {
      UserDefaults.standard.value(forKey: key.key) as? Value ?? key.defaultValue
    }

    set {
      UserDefaults.standard.set(newValue, forKey: key.key)
    }
  }
}
