import Combine

public extension Publisher {
  /// Buffers elements received from an upstream publisher infinitely.
  func bufferInfinitely() -> Publishers.Buffer<Self> {
    buffer(size: Int.max, prefetch: .keepFull, whenFull: .dropOldest)
  }
}
