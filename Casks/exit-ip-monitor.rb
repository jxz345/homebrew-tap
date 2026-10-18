# Cask for Exit IP Monitor. Update `version` and `sha256` after each release, taking both
# from the release's SHA256SUMS (Scripts/package-release.sh prints them). Background:
# https://github.com/jxz345/exit-ip-widget#first-launch
cask "exit-ip-monitor" do
  version "1.0"
  sha256 "ddabe35f966336383972b241158bf3041505536473748e13fd323e10872a52c2"

  url "https://github.com/jxz345/exit-ip-widget/releases/download/v#{version}/ExitIPMonitor-#{version}.zip"
  name "Exit IP Monitor"
  desc "Menu-bar app and widget showing your public exit IP address and country"
  homepage "https://github.com/jxz345/exit-ip-widget"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "ExitIPMonitor.app"

  # One administrator prompt at install and reinstall sets up the Tailscale → Clash Verge provider
  # daemon and its removal grant, like Sleepless's service. Apple's /bin/bash runs the bundled
  # script, which takes the user from SUDO_USER and prints whether Tailscale and Clash Verge Rev
  # are installed; neither is required. Skipped while the user has turned the daemon off
  # (`daemon.sh remove`). A busy port must not fail the install, so the step may fail.
  postflight_steps do
    unless_path_exists "Library/Application Support/ExitIPMonitor/tailscale-verge-off", base: :home do
      run "/bin/bash",
          args:         ["{{appdir}}/ExitIPMonitor.app/Contents/Resources/daemon.sh", "install"],
          sudo:         true,
          must_succeed: false,
          print_stdout: true
    end
  end

  # The daemon is removed here too, so deleting the app never leaves root code running; the new
  # version's postflight sets it up again on upgrade. The script runs only the commands the
  # removal grant allows, with sudo -n, because Homebrew's own `launchctl` and `delete` stanzas
  # always ask for a password; without the grant it prints the command to run instead. The
  # grant goes last, once nothing else remains (daemon.sh install writes it again).
  uninstall quit:   "com.example.exitipmonitor",
            script: {
              executable: "/bin/bash",
              args:       ["-c", <<~SH],
                set -uo pipefail
                label=com.example.exitipmonitor.tailscale-verge
                http="$label-http"
                plist="/Library/LaunchDaemons/$label.plist"
                http_plist="/Library/LaunchDaemons/$http.plist"
                support="/Library/Application Support/ExitIPMonitor"
                grant=/etc/sudoers.d/exitipmonitor-tailscale-verge
                present() { [ -e "$plist" ] || [ -e "$http_plist" ] || [ -e "$support" ]; }
                if present; then
                  /usr/bin/sudo -n /bin/launchctl bootout "system/$http" 2>/dev/null || true
                  /usr/bin/sudo -n /bin/launchctl bootout "system/$label" 2>/dev/null || true
                  /usr/bin/sudo -n /bin/rm -f "$http_plist" 2>/dev/null || true
                  /usr/bin/sudo -n /bin/rm -f "$plist" 2>/dev/null || true
                  /usr/bin/sudo -n /bin/rm -rf "$support" 2>/dev/null || true
                fi
                if present; then
                  echo "Could not remove the Tailscale → Clash Verge daemon without a password. Run:" >&2
                  echo "  sudo /bin/bash '#{appdir}/ExitIPMonitor.app/Contents/Resources/daemon.sh' remove" >&2
                  echo "or, if the app is gone:" >&2
                  echo "  sudo launchctl bootout system/$http; sudo launchctl bootout system/$label; sudo rm -rf '$plist' '$http_plist' '$support' $grant" >&2
                elif [ -e "$grant" ]; then
                  /usr/bin/sudo -n /bin/rm -f "$grant" 2>/dev/null || true
                fi
              SH
            }

  # Settings, the last result, runtime logs, the generated Clash Verge profile, and the daemon's
  # opt-out marker. Builds before 1.0's final upload ran sandboxed, so their containers are
  # removed too. The grant is normally gone already (uninstall deletes it last).
  zap delete: "/etc/sudoers.d/exitipmonitor-tailscale-verge",
      trash:  [
        "~/Library/Application Support/ExitIPMonitor",
        "~/Library/Containers/com.example.exitipmonitor",
        "~/Library/Containers/com.example.exitipmonitor.widgets",
        "~/Library/Group Containers/group.com.example.exitipmonitor",
        "~/Library/Preferences/com.example.exitipmonitor.plist",
        "~/Library/Preferences/group.com.example.exitipmonitor.plist",
      ]

  caveats <<~EOS
    Exit IP Monitor is ad-hoc signed (not notarized). Launch it, then try
    System Settings > Privacy & Security > "Open Anyway" if macOS blocks it.
    It is a menu-bar app: the dashboard opens on first launch and whenever
    you open the app again, and the country flag is in the menu bar.

    If launch hangs or "Open Anyway" is absent or ineffective, first close any
    "ExitIPMonitor" Not Opened dialog with Done (later launches wait on it), quit
    the stalled app, and after verifying it, remove quarantine for this app only:
      pkill -x ExitIPMonitor
      codesign --verify --deep --strict --verbose=2 "#{appdir}/ExitIPMonitor.app"
      xattr -dr com.apple.quarantine "#{appdir}/ExitIPMonitor.app"
      open "#{appdir}/ExitIPMonitor.app"
    If it still hangs, restart the Mac (ending any pending evaluation) and open it.
    If xattr reports "Operation not permitted", allow the terminal's host app
    under Privacy & Security > App Management, then retry.
    Details: https://github.com/jxz345/exit-ip-widget#first-launch

    Installing asks for your administrator password once, to set up the
    Tailscale → Clash Verge provider daemon (http://127.0.0.1:18766). It is
    useful only with Tailscale and Clash Verge Rev; without them it serves
    Reject and the dashboard says what's missing. Uninstall removes it without
    a password. Turn it off (reinstalls respect that) or back on with:
      sudo /bin/bash "#{appdir}/ExitIPMonitor.app/Contents/Resources/daemon.sh" remove
      sudo /bin/bash "#{appdir}/ExitIPMonitor.app/Contents/Resources/daemon.sh" install
    Details: https://github.com/jxz345/exit-ip-widget#tailscale--clash-verge-provider-root-daemon
  EOS
end
