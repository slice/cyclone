@testable import Serpent
import XCTest

class SerpentTests: XCTestCase {
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

  func testPrivateChannelSorting() {
    let privateChannels: [PrivateChannel] = [
      .dm(DMChannel(id: 1, lastMessageID: nil, recipientIDs: [])),
      .groupDM(GroupDMChannel(id: 2, icon: nil, lastMessageID: .init(id: 5), lastPinTimestamp: nil, name: nil, ownerID: .init(id: 100), recipients: [])),
      .dm(DMChannel(id: 3, lastMessageID: nil, recipientIDs: []))
    ]

    XCTAssertEqual(privateChannels.sortedChronologically().map(\.id), [2, 3, 1])
  }
}
