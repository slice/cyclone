extension Decoder {
  /// Decodes a single integer represented as a string.
  func decodeSingleIntString() throws -> Int {
    let container = try singleValueContainer()
    let string = try container.decode(String.self)
    guard let int = Int(string) else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "The integer string is too large to fit into a real integer.")
    }
    return int
  }
}
