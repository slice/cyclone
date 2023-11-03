# Cyclone

![A screenshot of Cyclone.](https://awo.oooooooooooooo.ooo/i/8x53t.jpg)

Cyclone is a **work in progress** third-party [Discord](https://discord.com/)
client for Macs.

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

## Usage

> [!IMPORTANT]
> **Disclaimer:** In its current state, Cyclone lacks many essential features
> necessary for basic use. It is not intended for end-users at this time, and
> resembles something more akin to an experiment than a fully fledged
> client. Consider exploring alternatives such as [Accord] or [Swiftcord].

[accord]: https://github.com/evelyneee/accord
[swiftcord]: https://github.com/SwiftcordApp/Swiftcord

1. After building and running, when the app activates, press Command-Comma to
   open the Settings window. (At the moment, Cyclone doesn't create any windows
   upon startup by default.)
1. Navigate to the Accounts tab and create a new account, inputting a Discord
   user token.
   - To enable compression, append `&compress=zlib-stream` to the gateway URL.
     Cyclone will automatically detect the presence of this parameter and
     decompress packets.
1. Back in Xcode, press Command-Shift-Comma to open the scheme editor.
1. In the Run scheme, under the Arguments tab, add an entry under "Arguments
   Passed on Launch".
1. Input `-BSLKAutomaticallyAuthorizeWithFirstAccount YES` and ensure that the
   argument is enabled by ticking the checkbox.
1. Stop the app and relaunch. The app will automatically attempt to connect to
   Discord with the first account present in the Settings window.
