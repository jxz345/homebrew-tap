# jxz345 Homebrew Tap

A [Homebrew](https://brew.sh) tap for [jxz345/Sleepless](https://github.com/jxz345/Sleepless), a fork of
[Aboudjem/Sleepless](https://github.com/Aboudjem/Sleepless) (this tap is forked from
[Aboudjem/homebrew-tap](https://github.com/Aboudjem/homebrew-tap)), and for
[Exit IP Monitor](https://github.com/jxz345/exit-ip-widget).

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

## Exit IP Monitor

```sh
brew install --cask jxz345/tap/exit-ip-monitor
open /Applications/ExitIPMonitor.app
```

The app is ad-hoc signed (not notarized). Approve the first launch in **System Settings → Privacy &
Security → Open Anyway**. If the launch hangs (the process starts but no menu-bar flag appears) or
**Open Anyway** is absent or ineffective, quit it, verify the app, and remove quarantine for this app
only:

```sh
pkill -x ExitIPMonitor
codesign --verify --deep --strict --verbose=2 /Applications/ExitIPMonitor.app
xattr -dr com.apple.quarantine /Applications/ExitIPMonitor.app
open /Applications/ExitIPMonitor.app
```

If `xattr` reports **Operation not permitted**, allow the terminal's host app (Terminal, or Visual
Studio Code) under **Privacy & Security → App Management**, then retry.

```sh
brew uninstall --cask jxz345/tap/exit-ip-monitor          # quits and removes the app
brew uninstall --zap --cask jxz345/tap/exit-ip-monitor    # also removes settings and logs
```

## Casks

- **sleepless** (`<upstream version>-jxz.<n>`): keep your Mac awake with the lid closed, on battery,
  with no external display. The fork adds a custom auto-off timer (1 min to 24 h), restores normal
  sleep when the app is quit or uninstalled, and steadies the menu-bar icon. See
  [jxz345/Sleepless](https://github.com/jxz345/Sleepless).
- **exit-ip-monitor**: a menu-bar app, desktop widget, and Control Center control showing your
  public exit IP address and country, with confirmed country-change alerts. See
  [jxz345/exit-ip-widget](https://github.com/jxz345/exit-ip-widget).
