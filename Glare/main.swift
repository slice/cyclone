import ArgumentParser
import Contempt
import os

struct Chat: ParsableCommand {
  @Option(
    name: .shortAndLong,
    help: "The user token to connect to Discord with."
  )
  var token: String

  mutating func run() throws {
    let client = Client(branch: .canary, token: token)
    let log = Logger(subsystem: "zone.slice.Glare", category: "glare")

    Task {
      try! await client.http!.requestLandingPage()
      log.info("*** requested landing page, connecting to gateway now")
      client.connect()
    }

    dispatchMain()
  }
}

Chat.main()
