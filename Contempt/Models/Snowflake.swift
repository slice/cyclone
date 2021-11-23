public struct Snowflake: Hashable {
  public let uint64: UInt64

  public init(string: String) {
    uint64 = UInt64(string)!
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
