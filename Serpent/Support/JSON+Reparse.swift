import SwiftyJSON

extension SwiftyJSON.JSON {
  /// Attempts to parse this JSON blob into something that is decodable.
  func reparse<T: Decodable>() throws -> T {
    let decoder = SerpentJSONDecoder()
    // XXX: This operation is inherently wasteful.
    return try decoder.decode(T.self, from: encoded())
  }
}
