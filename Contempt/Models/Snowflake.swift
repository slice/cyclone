public struct Snowflake: Hashable {
  let uint64: UInt64

  init(string: String) {
    uint64 = UInt64(string)!
  }
}
