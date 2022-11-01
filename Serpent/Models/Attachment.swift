import UniformTypeIdentifiers

public struct Attachment: Identifiable {
  public let id: Snowflake
  public let filename: String
  public let description: String?
  public let contentType: UTType?
  public let size: Measurement<UnitInformationStorage>
  public let url: URL
  public let proxyURL: URL
  public let width: Int?
  public let height: Int?
  public let ephemeral: Bool?

  public init(fakeWithWidth _: Int, height _: Int) {
    self.id = 1
    self.filename = "fake.jpg"
    self.description = nil
    self.contentType = .jpeg
    self.size = Measurement(value: 1, unit: .megabytes)
    let width = (640 ... 1920).randomElement()!
    let height = (480 ... 1080).randomElement()!
    self.url = URL(string: "https://picsum.photos/\(width)/\(height)")!
    self.proxyURL = self.url
    self.width = width
    self.height = height
    self.ephemeral = false
  }
}

extension Attachment: Decodable {
  public init(from decoder: Decoder) throws {
    id = try decoder.decode("id")
    filename = try decoder.decode("filename")
    description = try decoder.decodeIfPresent("description")
    if let mimeType = try decoder.decodeIfPresent("content_type", as: String.self) {
      contentType = UTType(mimeType: mimeType)
    } else {
      contentType = nil
    }
    size = Measurement(value: try decoder.decode("size", as: Double.self), unit: UnitInformationStorage.bytes)
    url = try decoder.decode("url")
    proxyURL = try decoder.decode("proxy_url")
    height = try decoder.decodeIfPresent("height")
    width = try decoder.decodeIfPresent("width")
    ephemeral = try decoder.decodeIfPresent("ephemeral")
  }
}
