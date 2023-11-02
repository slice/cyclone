import Compression
import Foundation
import os.log
import zlib

private func kibibytes(_ kb: Int) -> Int {
  kb * 1024
}

/// Wraps a zlib `z_stream` to decompress Discord gateway packets.
final class Decompression {
  var stream: UnsafeMutablePointer<z_stream>
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
  }

  enum Error: Swift.Error {
    case initialization
    case incomplete
    case zlib(ZlibCode, String?)
  }

  init() {
    stream = .allocate(capacity: 1)
  }

  // Not using a buffer pointer here, since we'd like to point zlib into the
  // middle of the output buffer (handy after resizing).
  private func pointDestination(to buffer: UnsafeMutableRawPointer, available: Int) {
    stream.pointee.next_out = UnsafeMutablePointer(mutating: buffer.assumingMemoryBound(to: UInt8.self))
    stream.pointee.avail_out = UInt32(available)
  }

  // OK to use a buffer pointer here, since we have access to all of the input
  // upfront.
  private func pointSource(to buffer: UnsafeRawBufferPointer, available: Int) {
    // N.B. The zlib Swift interface wants a mutable pointer here despite the
    // actual C pointer being const. idk
    stream.pointee.next_in = UnsafeMutablePointer(mutating: buffer.baseAddress!.assumingMemoryBound(to: UInt8.self))
    stream.pointee.avail_in = UInt32(available)
  }

  private func initializeStream(decompressing: UnsafeRawBufferPointer) throws {
    // nil means that zlib will use malloc and free for (de)allocating.
    stream.pointee.zalloc = nil
    stream.pointee.zfree = nil
    stream.pointee.opaque = nil

    guard ZlibCode(rawValue: inflateInit_(stream, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))) == .ok else {
      throw Error.initialization
    }
  }

  /// Decompress a raw buffer of `DEFLATE` compressed bytes, returning the
  /// original data.
  func decompress(completeBuffer input: Data) throws -> Data {
    guard !input.isEmpty else {
      throw Error.incomplete
    }

    return try input.withUnsafeBytes { (inputBuffer: UnsafeRawBufferPointer) -> Data in
      if !hasInitializedStream {
        Self.log.debug("initializing stream for the first time")
        try initializeStream(decompressing: inputBuffer)
        hasInitializedStream = true
      }

      pointSource(to: inputBuffer, available: inputBuffer.count)
      stream.pointee.total_out = 0
      stream.pointee.total_in = 0

      // Default to 256 KiB. The READY payload can be quite large.
      var output = Data(count: kibibytes(256))

      while true {
        // Needed to prevent an overlapping access error when pointing the
        // destination.
        let outputSize = output.count

        try output.withUnsafeMutableBytes { (outputBuffer: UnsafeMutableRawBufferPointer) in
          // Point zlib to our output buffer, offsetting the pointer and
          // available count by how much we've decompressed already.
          let amountDecompressed = Int(stream.pointee.total_out)
          pointDestination(to: outputBuffer.baseAddress! + amountDecompressed, available: outputSize - amountDecompressed)

          switch ZlibCode(rawValue: inflate(stream, Z_SYNC_FLUSH)) {
          case .ok:
            break
          case .none:
            fatalError("zlib gave an unknown return code")
          case .data:
            throw Error.zlib(.data, String(cString: stream.pointee.msg))
          case .some(let code):
            throw Error.zlib(code, nil)
          }
        }

        if stream.pointee.avail_out != 0 {
          // If we have space remaining in the output buffer, then we're done.
          // Truncate the size of the output to how much we truly decompressed
          // so the caller won't read zeros.
          output.count = Int(stream.pointee.total_out)
          break
        } else {
          // Grow the capacity of the output buffer, maxing out to 8 MiB.
          let newCapacity = min(outputSize * 2, kibibytes(1024 * 8))
          if newCapacity != outputSize {
            // Newly allocated bytes are zeroed for us.
            output.count = newCapacity
          }

          Self.log.debug("exhausted output buffer, continuing (remaining: \(self.stream.pointee.avail_in), growing size from \(outputSize) to \(newCapacity))")
        }
      }

      return output
    }
  }

  deinit {
    Self.log.debug("decompression deinit")
    guard ZlibCode(rawValue: inflateEnd(stream)) == .ok else {
      fatalError("inflateEnd failed")
    }
    stream.deinitialize(count: 1)
    stream.deallocate()
  }
}
