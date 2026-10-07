# jxz345 Homebrew Tap

A [Homebrew](https://brew.sh) tap for [jxz345/Sleepless](https://github.com/jxz345/Sleepless), a fork of
[Aboudjem/Sleepless](https://github.com/Aboudjem/Sleepless) (this tap is forked from
[Aboudjem/homebrew-tap](https://github.com/Aboudjem/homebrew-tap)).

## Install

```sh
brew install --cask jxz345/tap/sleepless
```

Approve the first launch in **System Settings → Privacy & Security → Open Anyway** (the app is
ad-hoc signed), then run the one-time passwordless grant (bundled inside the app) so it can toggle
lid-close sleep without a password prompt:

```sh
/Applications/Sleepless.app/Contents/Resources/grant.sh
```

**Switching from the upstream cask?** Both install `/Applications/Sleepless.app` under the same
token, so remove the upstream one first:

```sh
brew uninstall --cask aboudjem/tap/sleepless
brew untap aboudjem/tap
```

## Uninstall

```sh
brew uninstall --cask jxz345/tap/sleepless         # quits the app, restores normal sleep
brew uninstall --zap --cask jxz345/tap/sleepless   # also removes the sudoers grant + prefs
```

## Casks

- **sleepless** (`<upstream version>-jxz.<n>`): keep your Mac awake with the lid closed, on battery,
  with no external display. The fork adds a custom auto-off timer (1 min to 24 h), restores normal
  sleep when the app is quit or uninstalled, and steadies the menu-bar icon. See
  [jxz345/Sleepless](https://github.com/jxz345/Sleepless).
