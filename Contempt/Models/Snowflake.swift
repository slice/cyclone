public struct Snowflake: Hashable {
  public let uint64: UInt64

  public init(string: String) {
    uint64 = UInt64(string)!
  }
}
