# Cyclone

Cyclone is a work in progress third-party [Discord](https://discord.com/) client
for Macs.

Goals, in order of descending priority:

1. Be a good macOS citizen. Follow Apple's
   [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos).
   Pursue utilitarianism, embrace unorthodox features, and cater to power users.
1. Present as a first-party client to Discord's servers. Enabling spam,
   automation, and abuse are not goals of Cyclone, but extra care is taken to
   avoid automated account bans.
1. Consume less CPU, memory, and energy than Discord's official client.
1. Facilitate easy debugging and inspection of network traffic to and from
   Discord's gateway and HTTP API.

## Requirements

Swift 5.9 (Xcode 15.0) or later is required to build. Cyclone targets macOS 12.4
(Monterey) or newer, and will not launch on older versions.
