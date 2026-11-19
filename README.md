# MTG Life

Life counter for **Magic: The Gathering (Commander)**, made to run on an **old iPad with iOS 8** (tested on an iPad 3, A5X, iOS 8.4.1).

Native Objective-C/UIKit app, no storyboards, built for **armv7** with the Xcode 13.4.1 toolchain running on current macOS.

## Install

Add the Cydia repository **https://douugr.github.io/repo/** (Cydia or Melder → Sources → Edit → Add) and install **MTG Life**.

## Features

- 2 to 6 players, with panels facing each side of the table
- Tap left/right for −1/+1; hold to repeat (speeds up to steps of 5)
- Recent change indicator (+3, −2…)
- Poison and commander damage per opponent (commander damage is also taken from life)
- Player marked as "ELIMINATED" at life ≤ 0, poison ≥ 10 or 21 from a single commander
- Rename players, pick who goes first, starting life 20/25/30/40
- The game is saved automatically and the screen stays on while playing

## Requirements (to build)

- Mac with **Xcode 13.4.1** extracted (only the toolchain is used). Newer Xcode versions can't build armv7.
- `ldid` (`brew install ldid`)
- To install without Cydia: a jailbroken iPad with **AppSync Unified** and `ideviceinstaller` (the one bundled with [Legacy iOS Kit](https://github.com/LukeZGD/Legacy-iOS-Kit) works)

## Build and install

```bash
# By default the script looks for ../Xcode-13.4.1.app; or point to it with X13:
export X13=/path/to/Xcode-13.4.1.app/Contents/Developer

./build.sh            # builds LifeCounter.ipa
./build.sh install    # builds and installs on the connected iPad
```

The script builds with `-arch armv7 -miphoneos-version-min=8.0` and `-Wunguarded-availability`, so the compiler warns if any API newer than iOS 8 is used.

## Structure

```
src/LCModel.*              model (players, game, persistence)
src/LCPlayerPanelView.*    each player's panel (gestures, counters)
src/LCGameViewController.* table layout and menu
src/main.m                 AppDelegate
```

## License

MIT, see [LICENSE](LICENSE). The icon is original, made for the project.
