import Compression
import Foundation
import os.log
import zlib

private func kibibytes(_ kb: Int) -> Int {
  kb * 1024
}

/// Wraps a long-lived zlib decompression stream to decompress Discord gateway
/// packets that are compressed with `zlib-stream`.
final class Decompression {
  var stream = z_stream()
  var hasInitializedStream: Bool = false
  static var log = Logger(subsystem: "zone.slice.Tempest", category: "decompression")

  /// Return codes returned by compression and decompression functions in zlib.
  enum ZlibCode: Int32 {
    case ok = 0
    case streamEnd = 1
    case needDictionary = 2
    case errno = -1
    case stream = -2
    case data = -3
    case memory = -4
    case buffer = -5
    case version = -6

    init(rawValueErroring rawValue: Int32) {
      guard let code = ZlibCode(rawValue: rawValue) else {
        fatalError("zlib gave an unknown return code")
      }
      self = code
    }
  }

  enum Error: Swift.Error {
    case initialization
    case incomplete
    case zlib(ZlibCode, String?)
  }

  // Not using a buffer pointer here, since we'd like to point zlib into the
  // middle of the output buffer (handy after resizing).
  private func pointDestination(to buffer: UnsafeMutableRawPointer, available: Int) {
    stream.next_out = UnsafeMutablePointer(mutating: buffer.assumingMemoryBound(to: UInt8.self))
    stream.avail_out = UInt32(available)
  }

  // OK to use a buffer pointer here, since we have access to all of the input
  // upfront.
  private func pointSource(to buffer: UnsafeRawBufferPointer) {
    // N.B. The zlib Swift interface wants a mutable pointer here despite the
    // actual C pointer being const. idk
    stream.next_in = UnsafeMutablePointer(mutating: buffer.baseAddress!.assumingMemoryBound(to: UInt8.self))
    stream.avail_in = UInt32(buffer.count)
  }

  private func initializeStream() throws {
    try withUnsafeMutablePointer(to: &stream) { pointer in
      guard ZlibCode(rawValue: inflateInit_(pointer, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))) == .ok else {
        throw Error.initialization
      }
    }
  }

  /// Resets the internal state of the decompression stream.
  ///
  /// If your gateway connection is severed for any reason, call this method so
  /// stale internal state isn't reused for a future connection.
  func reset() throws {
    try withUnsafeMutablePointer(to: &stream) { pointer in
      let code = ZlibCode(rawValueErroring: inflateReset(pointer))

      guard code == .ok else {
        throw Error.zlib(code, nil)
      }
    }
  }

  /// Decompresses a complete buffer of `zlib`-compressed bytes as part of an
  /// ongoing stream, returning the decompressed data.
  ///
  /// This function is designed to decompress `zlib`-wrapped data compressed
  /// with `DEFLATE`. The first binary message sent by the Discord gateway will
  /// necessarily contain a `zlib` header, and subsequent packets are contingent
  /// on previous ones being decompressed in order to be processed correctly.
  /// This is because it is assumed that a single decompression context is
  /// shared for the lifetime of the entire connection.
  ///
  /// The trailing end of the input data you provide must terminate with
  /// `00 00 ff ff`. It is assumed that the input passed to this method, when
  /// fully decompressed, will constitute a fully formed Discord gateway packet.
  func decompress(_ input: Data) throws -> Data {
    guard !input.isEmpty else {
      throw Error.incomplete
    }

    // Reset the out total after every packet so we can use it to offset the
    // output buffer accordingly after resizes.
    stream.total_out = 0

    return try input.withUnsafeBytes { inputBuffer in
      pointSource(to: inputBuffer)

      // Stream initialization is deferred until we're able to point the stream
      // to the input buffer, because zlib wants that.
      if !hasInitializedStream {
        Self.log.debug("initializing stream for the first time")
        try initializeStream()
        hasInitializedStream = true
      }

      // Default to 256 KiB. The READY payload can be quite large.
      var output = Data(count: kibibytes(256))

      while true {
        // Needed to prevent an overlapping access error when pointing the
        // destination.
        let outputSize = output.count

        try output.withUnsafeMutableBytes { outputBuffer in
          // Point zlib to our output buffer, offsetting the pointer and
          // available count by how much we've decompressed already.
          let amountDecompressed = Int(stream.total_out)
          pointDestination(to: outputBuffer.baseAddress! + amountDecompressed, available: outputSize - amountDecompressed)

          try withUnsafeMutablePointer(to: &stream) { streamPointer in
            let code = ZlibCode(rawValueErroring: inflate(streamPointer, Z_SYNC_FLUSH))
            switch code {
            case .ok:
              break
            case .data:
              throw Error.zlib(.data, String(cString: streamPointer.pointee.msg))
            default:
              throw Error.zlib(code, nil)
            }
          }
        }

        if stream.avail_out != 0 {
          // If we have space remaining in the output buffer, then we're done.
          // Truncate the size of the output to how much we truly decompressed
          // so the caller won't read zeros.
          output.count = Int(stream.total_out)
          break
        } else {
          // Grow the capacity of the output buffer, maxing out to 8 MiB.
          let newCapacity = min(outputSize * 2, kibibytes(1024 * 8))
          if newCapacity != outputSize {
            // Newly allocated bytes are zeroed for us.
            output.count = newCapacity
          }

          Self.log.debug("exhausted output buffer, continuing (remaining: \(self.stream.avail_in), growing size from \(outputSize) to \(newCapacity))")
        }
      }

      return output
    }
  }

  deinit {
    Self.log.debug("decompression deinit")
    withUnsafeMutablePointer(to: &stream) { pointer in
      guard ZlibCode(rawValue: inflateEnd(pointer)) == .ok else {
        fatalError("inflateEnd failed")
      }
    }
  }
}
