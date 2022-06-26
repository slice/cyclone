import Foundation

/// A `JSONDecoder` subclass suitable for decoding gateway and HTTP payloads
/// from Discord.
class SerpentJSONDecoder: JSONDecoder {
  override init() {
    super.init()
    dateDecodingStrategy = .iso8601
  }
}
