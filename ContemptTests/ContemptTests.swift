@testable import Contempt
import FineJSON
import XCTest

class ContemptTests: XCTestCase {
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testClientInitEndpoints() throws {
    _ = Client(branch: .stable, token: "t")
    _ = Client(branch: .ptb, token: "t")
    _ = Client(branch: .canary, token: "t")
  }

  func testDisguiseEncode() throws {
    let disguise = Disguise(
      userAgent: "???",
      capabilities: 0,
      os: "Mac OS X",
      browser: "Discord Client",
      releaseChannel: .canary,
      clientVersion: "0.0.278",
      osVersion: "21.2.0",
      osArch: "x64",
      systemLocale: "en-US",
      clientBuildNumber: 104_572,
      clientEventSource: nil
    )

    let expected = """
    {"os":"Mac OS X","browser":"Discord Client",\
    "release_channel":"canary","client_version":"0.0.278",\
    "os_version":"21.2.0","os_arch":"x64","system_locale":"en-US",\
    "client_build_number":104572,"client_event_source":null}
    """

    XCTAssertEqual(disguise.superPropertiesJSONString(), expected)
  }
}
