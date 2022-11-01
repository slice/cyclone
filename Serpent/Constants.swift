/// Important constants and URLs.
public enum Constants {
  /// The Discord epoch.
  ///
  /// The number of milliseconds to the first day of 2015 at midnight,
  /// relative to the Unix epoch. This is used to extract the timestamp from
  /// ``Snowflake``s.
  public static let discordEpoch: Int = 1_420_070_400_000

  /// The URL to the Discord CDN.
  public static let cdnURL = URL(string: "https://cdn.discordapp.com")!

  /// The main URL to the Discord website.
  public static let mainURL = URL(string: "https://discord.com")!

  /// The URL to the Discord gateway.
  public static let gatewayURL = URL(string: "wss://gateway.discord.gg")!
}
