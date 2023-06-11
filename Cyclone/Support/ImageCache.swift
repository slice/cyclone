import Cocoa
import Foundation

public enum ImageCacheError: Error {
  case downloadFailed
  case decodingFailed
}

actor ImageCache {
  private enum CacheEntry {
    case inProgress(Task<NSImage, Error>)
    case ready(NSImage)
  }

  public static let shared = ImageCache()

  private var cache: [URL: CacheEntry] = [:]

  private func downloadImage(at url: URL) async throws -> NSImage {
    let (data, response) = try await URLSession.shared.data(from: url)
    if (response as! HTTPURLResponse).statusCode != 200 {
      throw ImageCacheError.downloadFailed
    }
    guard let image = NSImage(data: data) else {
      throw ImageCacheError.decodingFailed
    }
    return image
  }

  func image(at url: URL) async throws -> NSImage? {
    if let cached = cache[url] {
      switch cached {
      case let .ready(image):
        return image
      case let .inProgress(handle):
        return try await handle.value
      }
    }

    let handle = Task {
      try await downloadImage(at: url)
    }

    cache[url] = .inProgress(handle)

    do {
      let image = try await handle.value
      cache[url] = .ready(image)
      return image
    } catch {
      cache[url] = nil
      throw error
    }
  }
}
