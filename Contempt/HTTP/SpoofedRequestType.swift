import Foundation

public enum SpoofedRequestType {
  /// A request made by page navigation.
  case navigation

  /// A request made by fetching in JavaScript.
  case xhr
}
