import Foundation

public enum Branch: String {
  case stable
  case ptb
  case canary
  case development

  var baseURL: URL? {
    switch self {
    case .stable:
      return URL(string: "https://discord.com")!
    case .ptb:
      return URL(string: "https://ptb.discord.com")!
    case .canary:
      return URL(string: "https://canary.discord.com")!
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
