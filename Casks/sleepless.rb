# Cask for the jxz345 fork of Sleepless. Update `version` and `sha256` after each
# release, taking both from the release's SHA256SUMS. Background:
# https://github.com/jxz345/Sleepless/blob/main/UPDATE_NOTES.md
cask "sleepless" do
  version "1.2.7-jxz.3"
  sha256 "8ece5e57db56441fed4af91bb072c282d888e338bf897072e3f37c72f36d13e4"

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

  # One administrator prompt at install and upgrade sets up the permission grant and the
  # background service. Apple's /bin/bash runs the bundled scripts (the same way the app's own
  # setup does), so nothing in the freshly installed bundle is executed directly; both scripts
  # take the user from SUDO_USER. Skipped when the user turned the service off in the popover.
  postflight_steps do
    unless_path_exists "Library/Application Support/Sleepless/service-off", base: :home do
      run "/bin/bash", args: ["{{appdir}}/Sleepless.app/Contents/Resources/grant.sh", "--yes"], sudo: true
      run "/bin/bash", args: ["{{appdir}}/Sleepless.app/Contents/Resources/daemon.sh", "install"], sudo: true
    end
  end

  # Quitting the app restores normal sleep (applicationWillTerminate). The script is a
  # backstop for a stale state with the app not running. Never delete the app while
  # sleep remains disabled. Call sudo directly to match the narrowly scoped grant.
  # This also runs during upgrades; preferences and the grant belong in zap only. The
  # background service is removed here too, so deleting the app never leaves root code
  # running; the new version's postflight sets it up again on upgrade. The script removes it
  # through the passwordless grant, because Homebrew's own `launchctl` and `delete` stanzas
  # always ask for a password; without the grant it prints the commands to run instead.
  uninstall quit:   "com.aboudjem.Sleepless",
            script: {
              executable: "/bin/bash",
              args:       ["-c", <<~SH],
                set -euo pipefail
                service=com.aboudjem.Sleepless.timer
                plist="/Library/LaunchDaemons/$service.plist"
                support="/Library/Application Support/Sleepless"
                /usr/bin/sudo -n /bin/launchctl bootout "system/$service" 2>/dev/null || true
                if [ -e "$plist" ] || [ -e "$support" ]; then
                  /usr/bin/sudo -n /bin/rm -f "$plist" 2>/dev/null || true
                  /usr/bin/sudo -n /bin/rm -rf "$support" 2>/dev/null || true
                fi
                if [ -e "$plist" ] || [ -e "$support" ]; then
                  echo "Could not remove the background service without a password. Run:" >&2
                  echo "  sudo launchctl bootout system/$service; sudo rm -rf '$plist' '$support'" >&2
                fi
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
        "~/Library/Application Support/Sleepless",
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

    Installing asks for your administrator password once, to set up the
    permission grant and the background service. The service opens Sleepless
    at login and keeps an auto-off timer running after logout and restart (it
    does nothing without a timer). Turn it off in the popover; upgrades respect
    that. Manual grant fallback:
      /bin/bash "#{appdir}/Sleepless.app/Contents/Resources/grant.sh"

    Uninstall removes the background service and restores normal sleep, and
    stops if that cannot be verified. The app's "Uninstall…" button opens
    Terminal for complete removal through Homebrew, including the login item,
    passwordless grant, preferences, and Homebrew receipt.
    For Homebrew's additional cleanup from Terminal:
      brew uninstall --zap --cask jxz345/tap/sleepless
  EOS
end
