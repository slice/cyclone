# ``Serpent``

Interact with Discord's gateway and API in a manner faithful to first-party clients.

## Overview

Serpent is a client library for Discord which makes a good faith attempt at
accurately replicating the behavior and subtleties of first-party clients. It is
suitable for use in unofficial applications and programs that connect to Discord
and authorize with a user account.

## Ethics Statement

Serpent is developed with the express intent of making it easier to create more
efficient, lean, and powerful Discord client applications. Although Serpent does
not safeguard against malicious use, it is not developed with malicious use
cases in mind. Please do not use Serpent to spam, abuse, or otherwise harm
Discord and its users.

## Topics

### Connecting

- ``Client``

### Low-level Connections

- ``GatewayConnection``
- ``HTTP``

### Essential Models

- ``Snowflake``
- ``Ref``

### Common Models

- ``Guild``
- ``Channel``
- ``Message``
