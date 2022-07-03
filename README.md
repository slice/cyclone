# Basilisk

Basilisk is a work in progress third-party [Discord](https://discord.com/)
client for Macs.

Goals, in order of descending priority:

1. Be a good macOS citizen. Follow the
   [macOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos/overview/themes/).
   Pursue utilitarianism and embrace unorthodox features.
1. Present as a first-party client to Discord's servers. Enabling spam,
   automation, and abuse are not goals of Basilisk, but extra care is taken to
   avoid automated account bans.
1. Consume less CPU, memory, and energy than Discord's official client.
1. Facilitate easy debugging and inspection of network traffic to and from
   Discord's gateway and HTTP API.

## Requirements

Swift 5.7 (Xcode 14.0) or later is required to build. Basilisk targets macOS
12.4 (Monterey) or newer, and will not launch on older versions.
