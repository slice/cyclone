import FineJSON
import RichJSONParser

/// A collection of identifying values and metadata that real Discord clients
/// send to Discord while `IDENTIFY`ing, and as part of all HTTP requests.
public struct Disguise: Codable {
  let userAgent: String
  let capabilities: Int
  let os: String
  let browser: String
  let releaseChannel: Branch
  let clientVersion: String
  let osVersion: String
  let osArch: String
  let systemLocale: String
  let clientBuildNumber: Int
  let clientEventSource: String?

  func superPropertiesJSON() -> JSON {
    .object(.init([
      "os": .string(self.os),
      "browser": .string(self.browser),
      "release_channel": .string(self.releaseChannel.rawValue),
      "client_version": .string(self.clientVersion),
      "os_version": .string(self.osVersion),
      "os_arch": .string(self.osArch),
      "system_locale": .string(self.systemLocale),
      "client_build_number": .number(String(self.clientBuildNumber)),
      "client_event_source": .null,
    ]))
  }

  /// Returns this `Disguise` as a JSON string that is suitable to use as a
  /// value in `X-Super-Properties` as well as when `IDENTIFY`ing.
  func superPropertiesJSONString() -> String {
    let jsonEncoder = FineJSONEncoder()
    jsonEncoder.optionalEncodingStrategy = .explicitNull
    jsonEncoder
      .jsonSerializeOptions = JSONSerializeOptions(isPrettyPrint: false)
    guard let data = try? jsonEncoder.encode(self.superPropertiesJSON()) else {
      fatalError("failed to encode super properties dictionary as JSON")
    }
    guard let text = String(data: data, encoding: .utf8) else {
      fatalError("encoded super properties dictionary was not valid UTF-8 text")
    }
    return text
  }
}
