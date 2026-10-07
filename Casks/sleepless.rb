# Cask for the jxz345 fork of Sleepless. Update `version` and `sha256` after each
# release, taking both from the release's SHA256SUMS. Background:
# https://github.com/jxz345/Sleepless/blob/main/UPDATE_NOTES.md
cask "sleepless" do
  version "1.2.7-jxz.1"
  sha256 "c1f5eed3e7185499120855948280272d8922fa2f79178eec9c95dbbd1cd94dd6"

  url "https://github.com/jxz345/Sleepless/releases/download/v#{version}/Sleepless-#{version}.zip"
  name "Sleepless"
  desc "Stay awake with the lid closed, on battery, with no external display"
  homepage "https://github.com/jxz345/Sleepless"

  livecheck do
    url :url
    regex(/^v?(\d+(?:\.\d+)+-jxz\.\d+)$/i)
    strategy :github_latest
  end

  depends_on macos: :tahoe

  app "Sleepless.app"

  # Quitting the app restores normal sleep (applicationWillTerminate). The script is a
  # backstop for a stale state with the app not running. It calls sudo -n DIRECTLY with
  # the exact argv the sudoers grant allows: `script ... sudo: true` would make Homebrew
  # run `sudo -E <env> --`, which the NOPASSWD rule (no SETENV) refuses, forcing a
  # password prompt. If the grant is already gone it fails silently; a reboot resets anyway.
  # These directives also run on `brew upgrade`, which is harmless (just turns it off).
  uninstall quit:   "com.aboudjem.Sleepless",
            script: {
              executable:   "/usr/bin/sudo",
              args:         ["-n", "/usr/bin/pmset", "-a", "disablesleep", "0"],
              must_succeed: false,
            }

  # The passwordless grant is removed only on --zap: putting it in `uninstall` would
  # delete it on every `brew upgrade`, forcing a re-grant each time.
  zap delete: "/etc/sudoers.d/sleepless-disablesleep",
      trash:  [
        "~/Library/LaunchAgents/com.aboudjem.Sleepless.plist",
        "~/Library/Preferences/com.aboudjem.Sleepless.plist",
      ]

  caveats <<~EOS
    This is the jxz345 fork of Sleepless. Do not install it alongside
    aboudjem/tap/sleepless: both install #{appdir}/Sleepless.app.

    Sleepless is ad-hoc signed (not notarized). Launch it, then try
    System Settings > Privacy & Security > "Open Anyway" if macOS blocks it.

    If launch hangs or "Open Anyway" is absent or ineffective, quit the stalled
    app. After verifying the download, explicitly remove quarantine for this app:
      codesign --verify --deep --strict --verbose=2 "#{appdir}/Sleepless.app"
      xattr -dr com.apple.quarantine "#{appdir}/Sleepless.app"
      open "#{appdir}/Sleepless.app"
    If xattr reports "Operation not permitted", allow the terminal's host app
    under Privacy & Security > App Management, then retry.
    Recovery details and checks:
      https://github.com/jxz345/Sleepless/blob/main/UPDATE_NOTES.md#8-installation-recovery-on-macos-27-2026-10-07

    Once the cup appears, enable keep-awake to set up the permission grant if
    needed. Manual fallback:
      /bin/bash "#{appdir}/Sleepless.app/Contents/Resources/grant.sh"

    Quitting or uninstalling Sleepless restores normal sleep. To also remove the
    passwordless sudoers grant and preferences, uninstall with:
      brew uninstall --zap --cask jxz345/tap/sleepless
  EOS
end
