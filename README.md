# danmaku

A small bullet-hell (danmaku) shooter written in [Odin](https://odin-lang.org) using `vendor:raylib`.

## Requirements

- [Odin compiler](https://odin-lang.org/docs/install/)

## Build & run

```sh
odin build src -out:danmaku
./danmaku
```

## Controls

| Key            | Action                              |
|----------------|--------------------------------------|
| Arrows / WASD  | Move                                 |
| Shift          | Focus mode (slow, precise movement) |
| Z / J          | Shoot                                |
| R              | Restart                              |

## Gameplay

Survive incoming enemies and their bullet patterns (ring spreads, aimed bursts, spirals) while scoring points by destroying enemies and grazing bullets. You have 3 lives; losing all of them ends the run. Press R to start a new one.
