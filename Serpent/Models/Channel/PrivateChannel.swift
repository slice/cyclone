private enum PrivateChannelError: Error {
  case channelWasNotDMOrGroupDM
}

/// An enumeration representing either a group DM or DM channel.
public enum PrivateChannel: Identifiable, Equatable {
  case groupDM(GroupDMChannel)
  case dm(DMChannel)

  public var lastMessageID: Ref<Message>? {
    switch self {
    case let .groupDM(gdm): return gdm.lastMessageID
    case let .dm(dm): return dm.lastMessageID
    }
  }

  public var id: Snowflake {
    switch self {
    case let .groupDM(channel): return channel.id
    case let .dm(channel): return channel.id
    }
  }

  public var type: ChannelType {
    switch self {
    case .groupDM: return ChannelType.groupDM
    case .dm: return ChannelType.dm
    }
  }

  /// Returns a human-friendly name for this private channel.
  public func name() -> String {
    switch self {
    case let .groupDM(gdm):
      let people = gdm.recipients.count + 1 == 1 ? "person" : "people"
      return "\(gdm.recipients.count) \(people)"
    case let .dm(dm):
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
