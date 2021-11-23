public struct Snowflake {
  let uint64: UInt64

  init(string: String) {
    self.uint64 = UInt64(string)!
  }
}
