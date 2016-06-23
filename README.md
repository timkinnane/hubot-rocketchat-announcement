# hubot-rocketchat-announcement
[![NPM version][npm-image]][npm-url]

Hubot script to send direct message announcements to Rocket.Chat users.

See [`src/rocketchat-announcement.coffee`](src/rocketchat-announcement.coffee) for full documentation.

## CAUTION

This is a pre-release alpha version, not suitable for production environments.

This package requires [rocketchat-bot-helpers](https://github.com/timkinnane/rocketchat-bot-helpers/) package added to
Rocket.Chat. That is an experimental package, not published to Meteor and must be manually installed.

## Installation

In hubot project repo, run:

`npm install hubot-rocketchat-announcement --save`

Then add **hubot-rocketchat-announcement** to your `external-scripts.json`:

```json
["hubot-rocketchat-announcement"]
```

## Configuration

None at present.

Feature roadmap will introduce ability to configure announcement levels and authentication.
At present levels are `ALERT`, `NOTICE`, `UPDATE`, `SOCIAL`.

Users will be able to reply to ignore future announcements per level, apart from ALERT.
Authentication for senders of announcements will allow permissions based on level.

e.g. Only admins can send ALERT, moderators can send NOTICE/UPDATE, users can send SOCIAL.

## Sample Interaction

### Immediate send

Use announcement level (e.g. ALERT) to send immediately.

`user1>> hubot ALERT Don't eat the blue cupcakes!`

Sends to all users (including user1)...

```
hubot>> Don't eat the blue cupcakes!
        [ALERT] sent by [@user1]
```

### Dialog send

Use NEW (optionally with level) to [start dialog](https://github.com/lmarkus/hubot-conversation) to produce announcements.

This method intended to handle more complicated announcements in roadmap, e.g. scheduling and user group targets.

```
user1>> hubot NEW
hubot>> @admin OK, I'll create a NOTICE from your next message.
        Reply with the message you'd like to send (or `cancel` within 30 seconds).
user1>> Don't eat the blue cupcakes!
```

Sends to all users...

```
hubot>> Don't eat the blue cupcakes!
        [NOTICE] sent by [@user1]
```

With level:

```
user1>> hubot NEW UPDATE
hubot>> @admin OK, I'll create a NOTICE from your next message.
        Reply with the message you'd like to send (or `cancel` within 30 seconds).
user1>> You may eat the pink cupcakes.
```

Sends to all users...

```
hubot>> You may eat the pink cupcakes.
        [UPDATE] sent by [@user1]
```


[npm-url]: https://npmjs.org/package/hubot-rocketchat-announcement
[npm-image]: http://img.shields.io/npm/v/hubot-rocketchat-announcement.svg?style=flat
