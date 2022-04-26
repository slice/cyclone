/// Used as a uniquely identifiable descriptor by Discord.
///
/// For more information, see: https://discord.com/developers/docs/reference#snowflakes
public struct Snowflake: Hashable {
  public let uint64: UInt64

  public init(string: String) {
    uint64 = UInt64(string)!
  }

  public init(uint64: UInt64) {
    self.uint64 = uint64
  }

  public var timestamp: Date {
    let discordEpoch: Double = 1_420_070_400_000.0
    let timestamp: Double = (Double(uint64 >> 22) + discordEpoch) / 1000.0
    return Date(timeIntervalSince1970: timestamp)
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
    guard let numeric = UInt64(try value.decode(String.self)) else {
      fatalError("snowflake couldn't fit into uint64, is the year 2154?")
    }
    uint64 = numeric
  }
}

extension Snowflake: Comparable {
  public static func < (_: Snowflake, rhs: Snowflake) -> Bool {
    rhs.uint64 < rhs.uint64
  }

  public static func == (lhs: Snowflake, rhs: Snowflake) -> Bool {
    lhs.uint64 == rhs.uint64
  }
}
