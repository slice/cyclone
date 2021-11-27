import GenericJSON

public struct Snowflake: Hashable {
  public let uint64: UInt64

  public init(string: String) {
    uint64 = UInt64(string)!
  }

  public init(uint64: UInt64) {
    self.uint64 = uint64
  }

  public init(json: JSON?) {
    uint64 = json.flatMap(\.stringValue).flatMap { UInt64($0) }!
  }

  public var timestamp: Date {
    let discordEpoch: Double = 1_420_070_400_000.0
    let timestamp: Double = (Double(uint64 >> 22) + discordEpoch) / 1000.0
    return Date(timeIntervalSince1970: timestamp)
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
