# elmbot

[<img src="https://github.com/Janiczek/elmbot/raw/master/docs/avatar.png" width="100" height="100">](https://github.com/Janiczek/elmbot/raw/master/docs/avatar.png)

Elmbot is a Slack bot evaluating your code!

<img src="https://github.com/Janiczek/elmbot/raw/master/docs/screencast.gif" width="486" height="441">

## Building, running, all that...

```
$ yarn
$ yarn build

$ cp config/config.json.example config/config.json
$ vim config.json
$ # write your Slack API Token there

$ node dist/app.js
```

For the bot to actually listen to messages, you'll have to invite it to a channel.

It will (should) only respond to `elmbot` followed by code wrapped in the three backticks.

You can install packages by writing `--- install username/package` on a line inside the evaluated code. There can be many of those:

```
--- install elm-community/list-extra
--- install elm-community/basics-extra

import Basics.Extra exposing (inTurns)
import List.Extra as LE

some elm expression that uses those
```

## TODO

- [ ] allow for declaring stuff (possibly by transforming that stuff into a `let ... in ...`) before evaluating the expression:
```
x = 1

if x == 2 then
  3
else
  4
```
- [ ] concurrently eval more expressions from more people (or at least queue them and don't crash)
