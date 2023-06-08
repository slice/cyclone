import Compression
import Foundation

class Decompression {
  static let bufferSize: Int = 1024 * 1024 * 16 // 16 mebibytes
  var streamPointer: UnsafeMutablePointer<compression_stream>
  var destinationBuffer: UnsafeMutablePointer<UInt8>

  /// An error thrown during decompression.
  enum Error: Swift.Error {
    case initialization
    case incomplete
    case processing
    case tooLarge
  }

  init() throws {
    self.streamPointer = .allocate(capacity: 1)
    self.destinationBuffer = .allocate(capacity: Self.bufferSize)
    try self.initializeStream()
  }

  private func resetDestination() {
    streamPointer.pointee.dst_ptr = self.destinationBuffer
    streamPointer.pointee.dst_size = Self.bufferSize
  }

  private func initializeStream() throws {
    self.streamPointer = .allocate(capacity: 1)
    let status = compression_stream_init(self.streamPointer, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
    guard status != COMPRESSION_STATUS_ERROR else {
      throw Error.initialization
    }
  }

  /// Decompress a raw buffer of `DEFLATE` compressed bytes, returning the
  /// original data.
  ///
  /// The buffer shouldn't contain a zlib header---for example, the bytes
  /// `78 da`.
  func decompress(completeBuffer data: Data) throws -> Data {
    try data.withUnsafeBytes { untypedPointer in
      let sourcePointer = untypedPointer.bindMemory(to: UInt8.self).baseAddress!

      streamPointer.pointee.src_size = data.count
      streamPointer.pointee.src_ptr = sourcePointer
      self.resetDestination()

      let status = compression_stream_process(self.streamPointer, 0)

      guard streamPointer.pointee.dst_size != 0 else {
        throw Error.tooLarge
      }

      guard status == COMPRESSION_STATUS_OK else {
        throw Error.processing
      }

      let writtenCount = Self.bufferSize - self.streamPointer.pointee.dst_size
      let outputData = Data(bytes: self.destinationBuffer, count: writtenCount)
      return outputData
    }
  }

  deinit {
    compression_stream_destroy(self.streamPointer)
    self.streamPointer.deallocate()
    self.destinationBuffer.deallocate()
  }
}