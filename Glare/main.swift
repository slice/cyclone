import ArgumentParser
import Contempt

struct Chat: ParsableCommand {
  @Option(
    name: .shortAndLong,
    help: "The user token to connect to Discord with."
  )
  var token: String

  mutating func run() throws {
    let client = Client(branch: .canary, token: token)
    client.connect()
    dispatchMain()
  }
}

Chat.main()
