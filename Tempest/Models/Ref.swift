/// A reference to a model.
///
/// Models that contain other models may opt to use a `Ref` instead of directly
/// nesting the model in order to establish a single source of truth. This is
/// useful when multiple models reference the same one, and can help avoid data
/// desynchronizations and data races.
public struct Ref<Model: Identifiable> {
  /// The snowflake of the referenced model.
  public let id: Snowflake

  public init(id: Snowflake) {
    self.id = id
  }
}

extension Ref: Hashable {}

public extension Identifiable where ID == Snowflake {
  /// Returns a `Ref` to this model.
  var ref: Ref<Self> {
    Ref(id: id)
  }
}

public extension Snowflake {
  /// Returns this snowflake as a `Ref`.
  func ref<T>() -> Ref<T> {
    Ref(id: self)
  }
}

extension Ref: Comparable {
  public static func < (lhs: Ref<Model>, rhs: Ref<Model>) -> Bool {
    lhs.id < rhs.id
  }
}

extension Ref: Decodable {
  public init(from decoder: Decoder) throws {
    self.id = try decoder.decodeSingleValue(as: Snowflake.self)
  }
}

extension Ref: Encodable {
  public func encode(to encoder: Encoder) throws {
    try encoder.encodeSingleValue(id)
  }
}
