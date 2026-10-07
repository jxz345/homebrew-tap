# Cask for the jxz345 fork of Sleepless. Update `version` and `sha256` after each
# release, taking both from the release's SHA256SUMS. Background:
# https://github.com/jxz345/Sleepless/blob/main/UPDATE_NOTES.md
cask "sleepless" do
  version "1.2.7-jxz.1"
  sha256 "2b85fbae94c08994c16563ffe5fa6a22e1f6cc13f68c983ff424b4bc34e6acc0"

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
  # backstop for a stale state with the app not running. Never delete the app while
  # sleep remains disabled. Call sudo directly to match the narrowly scoped grant.
  # This also runs during upgrades; preferences and the grant belong in zap only.
  uninstall quit:   "com.aboudjem.Sleepless",
            script: {
              executable: "/bin/bash",
              args:       ["-c", <<~SH],
                set -euo pipefail
                state() {
                  /usr/bin/pmset -g | /usr/bin/awk '$1 == "SleepDisabled" {print $2}'
                }
                current=$(state)
                case "$current" in
                  0) exit 0 ;;
                  1) ;;
                  *) echo "Cannot read the sleep setting; keeping Sleepless installed." >&2; exit 1 ;;
                esac
                if ! /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0 || [ "$(state)" != 0 ]; then
                  echo "Cannot restore normal sleep; keeping Sleepless installed." >&2
                  echo "Run: sudo /usr/bin/pmset -a disablesleep 0, then retry uninstall." >&2
                  exit 1
                fi
              SH
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

    Uninstall restores normal sleep and stops if that cannot be verified.
    The app's "Uninstall…" button opens Terminal for complete removal, including
    the login item, passwordless grant, preferences, and Homebrew receipt.
    For Homebrew's additional cleanup from Terminal:
      brew uninstall --zap --cask jxz345/tap/sleepless
  EOS
end
