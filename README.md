# hubot-rocketchat-announcement
[![NPM version][npm-image]][npm-url] [![Build Status][travis-image]][travis-url] [![Dependency Status][daviddm-image]][daviddm-url] [![Coverage Status][coveralls-image]][coveralls-url]

A hubot script to make DM announcements to Rocket.Chat users.

See [`src/rocketchat-announcement.coffee`](src/rocketchat-announcement.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install hubot-rocketchat-announcement --save`

Then add **hubot-rocketchat-announcement** to your `external-scripts.json`:

```json
["hubot-rocketchat-announcement"]
```

## Sample Interaction

```
user1>> hubot hello
hubot>> hello!
```

[npm-url]: https://npmjs.org/package/hubot-rocketchat-announcement
[npm-image]: http://img.shields.io/npm/v/hubot-rocketchat-announcement.svg?style=flat
[travis-url]: https://travis-ci.org/Tim Kinnane/hubot-rocketchat-announcement
[travis-image]: http://img.shields.io/travis/Tim Kinnane/hubot-rocketchat-announcement/master.svg?style=flat
[daviddm-url]: https://david-dm.org/Tim Kinnane/hubot-rocketchat-announcement.svg?theme=shields.io
[daviddm-image]: http://img.shields.io/david/Tim Kinnane/hubot-rocketchat-announcement.svg?style=flat
[coveralls-url]: https://coveralls.io/r/Tim Kinnane/hubot-rocketchat-announcement
[coveralls-image]: http://img.shields.io/coveralls/Tim Kinnane/hubot-rocketchat-announcement/master.svg?style=flat
