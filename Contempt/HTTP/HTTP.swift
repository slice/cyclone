import Foundation
import os
import SwiftyJSON
import Combine

public enum HTTPError: Error {
  case httpError(httpResponse: HTTPURLResponse, data: Data)
}

public enum HTTPMethod: String {
  case get = "GET"
  case post = "POST"
  case patch = "PATCH"
  case delete = "DELETE"
  case put = "PUT"
}

public struct HTTPLog {
  public let url: URL
  public let headers: [String: String]
  public let body: Data?
}

/// A facility to make HTTP requests to the Discord API.
public class HTTP {
  private var token: String
  private var disguise: Disguise

  /// The base URL to make API requests to.
  public var baseURL: URL

  private var log: Logger

  private var session: URLSession!
  private var cookieStorage: HTTPCookieStorage! {
    session.configuration.httpCookieStorage
  }


  /// A Combine subject for requests sent to Discord.
  public private(set) var requests = PassthroughSubject<(String, HTTPLog), Never>()

  /// A Combine subject for responses received from Discord.
  public private(set) var responses = PassthroughSubject<(Int, HTTPLog), Never>()

  init(baseURL: URL, token: String, disguise: Disguise) {
    self.baseURL = baseURL
    self.token = token
    self.disguise = disguise

    log = Logger(subsystem: "zone.slice.Contempt", category: "http")

    let configuration = URLSessionConfiguration.default
    configuration.httpCookieAcceptPolicy = .always
    configuration.httpShouldSetCookies = true

    session = URLSession(configuration: configuration)
  }

  /// The landing page of the client, constructed according to the `baseURL`.
  var landingPageURL: URL {
    baseURL.appendingPathComponent("channels").appendingPathComponent("@me")
  }

  /// Request the client landing page.
  ///
  /// This is useful to grab the initial set of cookies that should be used for
  /// any subsequent requests.
  public func requestLandingPage() async throws {
    var request = URLRequest(url: landingPageURL)
    request.httpMethod = "GET"
    _ = try await self.request(
      request,
      withSpoofedHeadersFor: .navigation
    )

    for cookie in cookieStorage.cookies ?? [] {
      log.info("initial cookie: \(cookie.name)=\(cookie.value)")
    }
  }

  /// Returns additional headers to use in a request for a specific type of
  /// spoofed request.
  private func additionalRequestHeaders(
    forSpoofedRequestType type: SpoofedRequestType,
    referrer: String
  ) -> [String: String] {
    var headers: [String: String] = [
      "Accept-Encoding": "gzip, deflate, br",
      "Accept-Language": disguise.systemLocale,
      "Cache-Control": "no-cache",
      "Pragma": "no-cache",
      "User-Agent": disguise.userAgent,
      "Referer": referrer,
    ]

    switch type {
    case .xhr:
      guard let superProperties = try? disguise.superProperties.encoded().base64EncodedString() else {
        fatalError("failed to encode super properties into base64")
      }
      headers.merge([
        "Sec-Fetch-Dest": "empty",
        "Sec-Fetch-Mode": "cors",
        "Sec-Fetch-Site": "same-origin",
        "Accept": "*/*",

        // Important. Don't omit.
        "X-Super-Properties": superProperties,

        "X-Discord-Locale": disguise.systemLocale,

        // Apple "reserves" the Authorization HTTP header (and many others)
        // to be handled exclusively by their own "URL Loading System". According
        // to the documentation, "if you set a value for one of these reserved
        // headers, the system may ignore the value you set, or overwrite it
        // with its own value, or simply not send it."
        //
        // I'm not quite sure how to do this any other way, so let's just do it
        // anyways. It seems to work for now.
        "Authorization": token,
      ], uniquingKeysWith: { _, new in new })
    case .navigation:
      headers.merge([
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9",
        "Sec-Fetch-Dest": "document",
        "Sec-Fetch-Mode": "navigate",
        "Sec-Fetch-Site": "none",
        "Sec-Fetch-User": "?1",
      ], uniquingKeysWith: { _, new in new })
    }

    return headers
  }

  /// Creates a `URLRequest` suitable to be passed to `request`.
  public func apiRequest(
    to pathComponents: String,
    query: [String: String] = [:],
    method: HTTPMethod = .get,
    body: JSON? = nil
  ) throws -> URLRequest? {
    guard var urlComponents = URLComponents(
      url: baseURL,
      resolvingAgainstBaseURL: false
    ) else {
      return nil
    }
    urlComponents.path += "/api/v9" + pathComponents
    urlComponents.queryItems = query.map { key, value in
      URLQueryItem(name: key, value: value)
    }

    guard let finalURL = urlComponents.url else {
      return nil
    }
    var request = URLRequest(url: finalURL)
    request.httpMethod = method.rawValue
    if let body = body {
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try body.encoded()
    }
    return request
  }

  /// Makes a request to a URL.
  public func request(
    _ request: URLRequest,
    withSpoofedHeadersFor type: SpoofedRequestType
  ) async throws -> (HTTPURLResponse, Data) {
    var request = request

    for (name, value) in additionalRequestHeaders(
      forSpoofedRequestType: type,
      referrer: landingPageURL.absoluteString
    ) {
      request.addValue(value, forHTTPHeaderField: name)
    }

    log.info("<- \(request.httpMethod!) \(request.url!.absoluteString)")

    requests.send((request.httpMethod!, HTTPLog(url: request.url!, headers: request.allHTTPHeaderFields!, body: request.httpBody)))

    let (data, response) = try await session.data(for: request, delegate: nil)
    let httpResponse = response as! HTTPURLResponse

    responses.send((httpResponse.statusCode, HTTPLog(url: request.url!, headers: httpResponse.allHeaderFields as! [String: String], body: data)))

    log
      .info(
        "-> HTTP \(httpResponse.statusCode), \(httpResponse.expectedContentLength) byte(s)"
      )

    if let string = String(data: data, encoding: .utf8) {
      log.info("-> \(string)")
    }

    if !(200 ..< 300).contains(httpResponse.statusCode) {
      throw HTTPError.httpError(httpResponse: httpResponse, data: data)
    }

    return (httpResponse, data)
  }

  /// Makes a request to a URL, decoding the response.
  public func requestDecoding<T: Decodable>(
    _ request: URLRequest,
    withSpoofedHeadersFor type: SpoofedRequestType
  ) async throws -> T {
    let (_, data) = try await self.request(request, withSpoofedHeadersFor: type)
    let decoder = JSONDecoder()
    return try decoder.decode(T.self, from: data)
  }
}
