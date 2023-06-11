import Combine

public extension Publisher {
  /// Buffers elements received from an upstream publisher infinitely.
  ///
  /// Without buffering, then any values received while the subscriber is busy
  /// will be dropped.
  func bufferInfinitely() -> Publishers.Buffer<Self> {
    buffer(size: Int.max, prefetch: .keepFull, whenFull: .dropOldest)
  }
}
