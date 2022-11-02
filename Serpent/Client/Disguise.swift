import Codextended
import Darwin

/// A subset of `Disguise` properties used when `IDENTIFY`ing and as the value
/// of the `X-Super-Properties` header.
internal struct SuperProperties: Codable {
  enum CodingKeys: String, CodingKey {
    case os
    case browser
    case releaseChannel = "release_channel"
    case clientVersion = "client_version"
    case osVersion = "os_version"
    case osArch = "os_arch"
    case systemLocale = "system_locale"
    case clientBuildNumber = "client_build_number"
    case clientEventSource = "client_event_source"
  }

  let os: String
  let browser: String
  let releaseChannel: String
  let clientVersion: String
  let osVersion: String
  let osArch: String
  let systemLocale: String
  let clientBuildNumber: Int
  let clientEventSource: String?

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(os, forKey: .os)
    try container.encode(browser, forKey: .browser)
    try container.encode(releaseChannel, forKey: .releaseChannel)
    try container.encode(clientVersion, forKey: .clientVersion)
    try container.encode(osVersion, forKey: .osVersion)
    try container.encode(osArch, forKey: .osArch)
    try container.encode(systemLocale, forKey: .systemLocale)
    try container.encode(clientBuildNumber, forKey: .clientBuildNumber)

    // Encode the optional event source directly, so it's present with a `null`
    // value.
    //
    // If we didn't do this, then the key would be left out, and we want to
    // resemble first-party Discord clients as accurately as possible.
    try container.encode(clientEventSource, forKey: .clientEventSource)
  }
}

/// A collection of identifying values and metadata that real Discord clients
/// send to Discord while `IDENTIFY`ing, and as part of all HTTP requests.
public struct Disguise: Codable {
  /// The HTTP `User-Agent`. Also used in the super properties.
  let userAgent: String

  /// A bitfield sent in `IDENTIFY`. Purpose unknown.
  let capabilities: Capabilities

  /// The operating system. This should probably be "Mac OS X".
  let os: String

  /// The browser used. Example values: "Discord Client", "Chrome".
  let browser: String

  /// The client release channel ("branch").
  let releaseChannel: Branch

  /// The version of the client host (i.e. the Electron application).
  let clientVersion: String

  /// The operating system version.
  let osVersion: String

  /// The architecture of the operating system.
  let osArch: String

  /// The first preferred locale of the system. This is sent in the super
  /// properties, used as the content of the `Accept-Language` header in
  /// every request, and is sent as another private header.
  let systemLocale: String

  /// The client build number. Discord ostensibly increments this number with
  /// each build of the client.
  let clientBuildNumber: Int

  /// Unknown field.
  let clientEventSource: String?

  var superProperties: SuperProperties {
    SuperProperties(
      os: os, browser: browser, releaseChannel: releaseChannel.rawValue,
      clientVersion: clientVersion, osVersion: osVersion, osArch: osArch,
      systemLocale: systemLocale, clientBuildNumber: clientBuildNumber,
      clientEventSource: clientEventSource
    )
  }
}
