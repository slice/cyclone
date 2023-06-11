import Foundation

/// A Discord release channel.
public enum Branch: String {
  /// The stable branch.
  ///
  /// This is the main branch that the vast majority of Discord users are using.
  case stable

  /// The PTB branch.
  case ptb

  /// The canary branch.
  case canary

  /// The development branch.
  ///
  /// A host is available for this branch, but the frontend is not accessible
  /// from the public internet.
  case development

  /// The base URL of the branch's frontend.
  ///
  /// ``development`` does not have a base URL.
  public var baseURL: URL? {
    func subdomain(_ subdomain: String) -> URL {
      var components = URLComponents(url: Constants.mainURL, resolvingAgainstBaseURL: false)!
      components.host = "\(subdomain).\(components.host!)"
      return components.url!
    }

    switch self {
    case .stable:
      return Constants.mainURL
    case .ptb:
      return subdomain("ptb")
    case .canary:
      return subdomain("canary")
    default:
      return nil
    }
  }
}

extension Branch: Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension Branch: Decodable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let string = try container.decode(String.self)
    self = Branch(rawValue: string)!
  }
}
