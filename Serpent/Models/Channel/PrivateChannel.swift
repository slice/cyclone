fileprivate enum PrivateChannelError: Error {
  case channelWasNotDMOrGroupDM
}

/// An enumeration representing either a group DM or DM channel.
public enum PrivateChannel: Identifiable {
  case groupDM(GroupDMChannel)
  case dm(DMChannel)

  public var id: Snowflake {
    switch self {
    case .groupDM(let channel): return channel.id
    case .dm(let channel): return channel.id
    }
  }

  public var type: ChannelType {
    switch self {
    case .groupDM(_): return ChannelType.groupDM
    case .dm(_): return ChannelType.dm
    }
  }

  /// Returns a human-friendly name for this private channel.
  public func name() -> String {
    switch self {
    case .groupDM(let gdm):
      let people = gdm.recipients.count + 1 == 1 ? "person" : "people"
      return "\(gdm.recipients.count) \(people)"
    case .dm(let dm):
      return dm.recipient!.id.string
    }
  }
}

extension PrivateChannel: Decodable {
  public init(from decoder: Decoder) throws {
    let type = ChannelType(rawValue: try decoder.decode("type"))

    if type == .dm {
      self = .dm(try DMChannel(from: decoder))
    } else if type == .groupDM {
      self = .groupDM(try GroupDMChannel(from: decoder))
    } else {
      throw PrivateChannelError.channelWasNotDMOrGroupDM
    }
  }
}
