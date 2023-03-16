import Foundation

enum BasiliskError: Int {
  case invalidAccountValues
  case invalidGivenURL
  case failedToSendMessage

  func wrap(underlyingError: Error) -> NSError {
    let userInfo = self.errorUserInfo.merging([NSUnderlyingErrorKey: underlyingError as Any], uniquingKeysWith: { $1 })
    return NSError(domain: Self.errorDomain, code: self.rawValue, userInfo: userInfo)
  }
}

extension BasiliskError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .invalidAccountValues: return "Couldn't save changes to your accounts."
    case .invalidGivenURL: return "The given URL was invalid."
    case .failedToSendMessage: return "Couldn't send message."
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .invalidAccountValues: return "Make sure that your account has well-formed data."
    case .invalidGivenURL: return "Make sure that the URL is well-formed."
    case .failedToSendMessage: return "Try sending the message again."
    }
  }
}

extension BasiliskError: CustomNSError {
  static var errorDomain: String = "zone.slice.Basilisk.ErrorDomain"

  var errorCode: Int {
    self.rawValue
  }

  var errorUserInfo: [String: Any] {
    [NSLocalizedDescriptionKey: self.errorDescription as Any,
     NSLocalizedRecoverySuggestionErrorKey: self.recoverySuggestion as Any]
  }
}
