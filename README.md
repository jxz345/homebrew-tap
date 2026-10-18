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
Security → Open Anyway**. Close any "ExitIPMonitor" Not Opened dialog with **Done** before
approving it. After approval, verify that the installed app completed startup:

```sh
/bin/bash /Applications/ExitIPMonitor.app/Contents/Resources/diagnose-launch.sh --launch --timeout 60
```

The check verifies the signature, installed build, and a live main-thread heartbeat. A process
appearing in Activity Monitor alone is not success. If startup times out, it saves bounded
diagnostics under `~/Library/Application Support/ExitIPMonitor/Logs`; daemon setup logs are under
`/Library/Logs/ExitIPMonitor`. Quarantine and macOS security settings remain intact. See
[launch diagnostics](https://github.com/jxz345/exit-ip-widget#launch-diagnostics).

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
