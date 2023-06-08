/// A uniquely identifier used by Discord that doubles as a timestamp.
///
/// For more information, see [Discord's documentation](https://discord.com/developers/docs/reference#snowflakes).
public struct Snowflake: Hashable {
  /// The snowflake as an unsigned 64-bit integer.
  public let uint64: UInt64

  /// Creates a snowflake from a string.
  ///
  /// All snowflakes that originate from Discord's gateway or HTTP API are
  /// strings, because JavaScript lacks the numeric precision for snowflakes.
  public init(string: String) {
    uint64 = UInt64(string)!
  }

  /// Creates a snowflake from an unsigned 64-bit integer.
  public init(uint64: UInt64) {
    self.uint64 = uint64
  }

  /// The timestamp associated with the snowflake.
  ///
  /// Snowflakes internally contain a timestamp relative to the Discord epoch.
  public var timestamp: Date {
    let timestamp = (Double(uint64 >> 22) + Double(Constants.discordEpoch)) / 1000.0
    return Date(timeIntervalSince1970: timestamp)
  }

  /// The snowflake represented textually as a string.
  public var string: String {
    String(uint64)
  }
}

extension Snowflake: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: IntegerLiteralType) {
    uint64 = UInt64(clamping: value)
  }
}

extension Snowflake: Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(String(uint64))
  }
}

extension Snowflake: Decodable {
  public init(from decoder: Decoder) throws {
    let value = try decoder.singleValueContainer()
    guard let numeric = try UInt64(value.decode(String.self)) else {
      fatalError("snowflake couldn't fit into uint64, is the year 2154?")
    }
    uint64 = numeric
  }
}

extension Snowflake: Comparable {
  public static func < (lhs: Snowflake, rhs: Snowflake) -> Bool {
    lhs.uint64 < rhs.uint64
  }

  public static func == (lhs: Snowflake, rhs: Snowflake) -> Bool {
    lhs.uint64 == rhs.uint64
  }
}
