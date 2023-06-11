import Foundation

/// A structure that encapsulates various data about an HTTP request for logging
/// purposes.
public struct HTTPLog {
  /// The HTTP method used to make the request.
  public let method: HTTPMethod

  /// The URL that the request was made to.
  public let url: URL

  /// The HTTP status code that was sent by the server.
  public let statusCode: Int

  /// The request headers sent to the server.
  public let requestHeaders: [String: String]

  /// The response headers sent by the server.
  public let responseHeaders: [String: String]

  /// The request body.
  public let requestBody: Data?

  /// The response body.
  public let responseBody: Data?
}
