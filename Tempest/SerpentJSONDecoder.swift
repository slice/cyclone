import Foundation

/// A `JSONDecoder` subclass suitable for decoding gateway and HTTP payloads
/// from Discord.
class SerpentJSONDecoder: JSONDecoder {
  override init() {
    super.init()
    dateDecodingStrategy = .custom { decoder in
      let iso8601Timestamp = try decoder.decodeSingleValue(as: String.self)

      // Discord timestamps have fractional seconds, but only some of the time.
      let formatStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: iso8601Timestamp.contains("."))
      return try formatStyle.parse(iso8601Timestamp)
    }
  }
}
