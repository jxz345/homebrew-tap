# Cask for Exit IP Monitor. Update `version` and `sha256` after each release, taking both
# from the release's SHA256SUMS (Scripts/package-release.sh prints them). Background:
# https://github.com/jxz345/exit-ip-widget#first-launch
cask "exit-ip-monitor" do
  version "1.0"
  sha256 "4f4e33ea5d4efa405a9a9647c3260d95ea324fada989372711a2cef676c6fa93"

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

  uninstall quit: "com.example.exitipmonitor"

  # Settings, the last result, and runtime logs. Builds before 1.0's final upload ran sandboxed,
  # so their containers are removed too.
  zap trash: [
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
  EOS
end
