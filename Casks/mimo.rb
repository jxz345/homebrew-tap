# frozen_string_literal: true

# Cask for Mimo. Update `version` and `sha256` after each release, taking both
# from the release's SHA256SUMS (Scripts/package-release.sh prints them). Background:
# https://github.com/jxz345/mimo#first-launch
cask "mimo" do
  version "1.0"
  sha256 "7bb6026ae096fae7f047ca39c29d295f377e880d8da7fbd2138be81f35e23aef"

  url "https://github.com/jxz345/mimo/releases/download/v#{version}/Mimo-#{version}.zip"
  name "Mimo"
  desc "IPv4 proxy routing and exit-IP monitoring"
  homepage "https://github.com/jxz345/mimo"

  depends_on macos: :sonoma
  depends_on arch: :arm64
  depends_on formula: "jxz345/tap/mihomo@1.19.34"

  conflicts_with cask: "exit-ip-monitor"

  app "Mimo.app"

  # Ad-hoc signed, not notarized. A quarantined copy needs Gatekeeper's Open Anyway, which
  # macOS 27 can cancel itself (Use Password), holding the app before startup until the next
  # screen unlock or restart. Before the app is moved into place, verify its sealed signature
  # and remove only its download quarantine (Sleepless's app-scoped recovery, applied before
  # the first launch). See https://github.com/jxz345/mimo#first-launch
  preflight_steps do
    run "/usr/bin/codesign", args: ["--verify", "--deep", "--strict", "{{staged_path}}/Mimo.app"]
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{staged_path}}/Mimo.app"]
  end

  # One machine-wide service is required for monitoring. Failed/cancelled authentication leaves
  # the app installed with an Install Service action; optional Tailscale enablement is separate.
  postflight_steps do
    run "/bin/bash",
        args:         ["{{appdir}}/Mimo.app/Contents/Resources/daemon.sh", "install"],
        sudo:         true,
        must_succeed: false,
        print_stdout: true
  end

  # Uninstall removes owned services/PF/runtime and per-user login items through its fixed removal grant.
  # The inline helper also supports installed releases without cleanup-installation.sh.
  # Keep in sync with Scripts/sync-homebrew-cleanup.py in mimo.
  uninstall quit:   "com.mimo",
            script: {
              executable:   "/bin/bash",
              must_succeed: true,
              args:         ["-c", <<~'SH', "--", "#{appdir}/Mimo.app"],
                # BEGIN GENERATED CLEANUP
                #!/bin/bash
                # Shared by the release installer, launch diagnostics, and daemon setup. Bash 3.2 compatible.
                # No xtrace: command arguments can contain private data. Log descriptive step names instead.

                step_log() { printf '%s %-6s %s\n' "$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" >&2; }

                # BSD mktemp only randomizes trailing Xs (a trailing .log would produce a literal filename).
                new_step_log() { /usr/bin/mktemp "$1/$2-XXXXXXXX"; }

                # Each command gets its own process group, so a timed-out command's children cannot keep
                # Homebrew's output pipe open. Only that group is terminated; unrelated jobs are untouched.
                bounded_command() (
                    set +e
                    local limit=$1 label=$2 pid ticks=0 status started=$SECONDS
                    shift 2
                    step_log BEGIN "$label (timeout ${limit}s)"
                    set -m
                    "$@" &
                    pid=$!
                    set +m
                    trap '/bin/kill -TERM -- "-$pid" 2>/dev/null; /bin/sleep 0.2; /bin/kill -KILL -- "-$pid" 2>/dev/null; exit 130' INT TERM
                    while /bin/kill -0 "$pid" 2>/dev/null; do
                        if [ "$ticks" -ge "$((limit * 10))" ]; then
                            /bin/kill -TERM -- "-$pid" 2>/dev/null || true
                            /bin/sleep 0.2
                            /bin/kill -KILL -- "-$pid" 2>/dev/null || true
                            wait "$pid" 2>/dev/null || true
                            step_log ERROR "$label timed out after $((SECONDS - started))s (status 124)"
                            exit 124
                        fi
                        /bin/sleep 0.1
                        ticks=$((ticks + 1))
                    done
                    wait "$pid" 2>/dev/null
                    status=$?
                    step_log END "$label status=$status elapsed=$((SECONDS - started))s"
                    exit "$status"
                )

                #!/bin/bash
                # Prepare a clean uninstall/reinstall without running application code.
                # Usage: /bin/bash cleanup-installation.sh --app /Applications/Mimo.app
                # Stops only this bundle's processes and removes the optional provider. Does not delete the
                # app, user settings, credentials or logs, install anything, or change macOS security settings.
                # The cask embeds this file plus command-support.sh so cleanup also works with older bundles.

                if ! declare -F bounded_command >/dev/null; then
                    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/command-support.sh"
                fi

                cleanup_process_table() { bounded_command 5 inspect-processes /bin/ps -axww -o pid=,uid=,lstart=,comm= 2>/dev/null; }
                cleanup_command_table() { bounded_command 5 inspect-workers /bin/ps -axww -o pid=,command= 2>/dev/null; }
                cleanup_pause() { /bin/sleep 0.2; }
                cleanup_signal() { /bin/kill -"$1" "$2"; }
                cleanup_exists() { [ -e "$1" ] || [ -L "$1" ]; }

                cleanup_translocation_matches() {
                    local running=$1 expected actual
                    case "$running" in
                        /private/var/folders/*/T/AppTranslocation/*/d/Mimo.app|/var/folders/*/T/AppTranslocation/*/d/Mimo.app|/private/var/folders/*/T/AppTranslocation/*/d/ExitIPMonitor.app|/var/folders/*/T/AppTranslocation/*/d/ExitIPMonitor.app) ;;
                        *) return 1 ;;
                    esac
                    # Cache validated bundle paths within this invocation, never across uninstall attempts.
                    case "${cleanup_translocations:-}" in *"|$running|"*) return 0 ;; esac
                    expected=$(bounded_command 5 identity /usr/bin/codesign -d --arch "$(/usr/bin/uname -m)" --verbose=4 "$cleanup_app" 2>&1 |
                        /usr/bin/sed -n 's/^CDHash=//p')
                    actual=$(bounded_command 5 identity /usr/bin/codesign -d --arch "$(/usr/bin/uname -m)" --verbose=4 "$running" 2>&1 |
                        /usr/bin/sed -n 's/^CDHash=//p')
                    [ -n "$expected" ] && [ "$expected" = "$actual" ] || return 1
                    bounded_command 5 translocation-signature /usr/bin/codesign --verify --deep --strict "$running" || return 1
                    cleanup_translocations="${cleanup_translocations:-}|$running|"
                }

                # A failed inspection is an error, never an empty process list. The start time and executable
                # are retained with each PID and checked again immediately before sending a signal.
                cleanup_find_processes() {
                    local table pid uid weekday month day time year path running
                    cleanup_matches=()
                    table=$(cleanup_process_table) || { step_log ERROR 'Cannot inspect app processes.'; return 1; }
                    [ -n "$table" ] || { step_log ERROR 'Process inspection returned no data.'; return 1; }
                    while read -r pid uid weekday month day time year path; do
                        case "$path" in */Contents/MacOS/mimo-gui|*/Contents/MacOS/ExitIPMonitor) ;; *) continue ;; esac
                        [[ "$pid" =~ ^[0-9]+$ && "$uid" =~ ^[0-9]+$ ]] && [ "$pid" -gt 1 ] && [ -n "$year" ] || return 1
                        running=${path%/Contents/MacOS/*}
                        if [ "$running" != "$cleanup_app" ] && ! [ "$running" -ef "$cleanup_app" ]; then
                            case "$running" in
                                */T/AppTranslocation/*/d/Mimo.app|*/T/AppTranslocation/*/d/ExitIPMonitor.app)
                                    cleanup_translocation_matches "$running" || {
                                        step_log ERROR "Cannot associate translocated process $pid with the target app; leaving it untouched."
                                        return 1
                                    } ;;
                                *) continue ;;
                            esac
                        fi
                        [ "$uid" = "$cleanup_uid" ] || [ "$cleanup_uid" = 0 ] || {
                            step_log ERROR "Target app process $pid belongs to user $uid; it was not signalled."
                            return 1
                        }
                        cleanup_matches+=("$pid|$uid|$weekday $month $day $time $year|$path")
                    done <<< "$table"
                }

                cleanup_signal_matches() {
                    local signal=$1 candidate current pid still_present
                    local targets=("${cleanup_matches[@]:-}")
                    for candidate in "${targets[@]}"; do
                        cleanup_find_processes || return 1
                        still_present=0
                        for current in "${cleanup_matches[@]:-}"; do
                            [ "$candidate" != "$current" ] || still_present=1
                        done
                        [ "$still_present" = 1 ] || continue
                        pid=${candidate%%|*}
                        step_log INFO "Sending $signal to verified app process $pid."
                        if ! cleanup_signal "$signal" "$pid"; then
                            cleanup_find_processes || return 1
                            for current in "${cleanup_matches[@]:-}"; do
                                if [ "$candidate" = "$current" ]; then
                                    step_log ERROR "Could not send $signal to app process $pid."
                                    return 1
                                fi
                            done
                        fi
                    done
                }

                cleanup_wait_for_app() {
                    local ticks=0 started=$SECONDS
                    while [ "$ticks" -lt 25 ] && [ "$((SECONDS - started))" -lt 5 ]; do
                        cleanup_find_processes || return 2
                        [ "${#cleanup_matches[@]}" -ne 0 ] || return 0
                        cleanup_pause
                        ticks=$((ticks + 1))
                    done
                    return 1
                }

                cleanup_stop_app() {
                    local status
                    cleanup_find_processes || return 1
                    if [ "${#cleanup_matches[@]}" -gt 0 ]; then
                        cleanup_signal_matches TERM || return 1
                        status=0; cleanup_wait_for_app || status=$?
                        [ "$status" != 2 ] || return 1
                        if [ "$status" != 0 ]; then
                            cleanup_signal_matches KILL || return 1
                            cleanup_wait_for_app || {
                                step_log ERROR "App processes remain after KILL: ${cleanup_matches[*]:-}"
                                return 1
                            }
                        fi
                    fi
                    cleanup_pause
                    cleanup_find_processes || return 1
                    [ "${#cleanup_matches[@]}" = 0 ] || { step_log ERROR 'The app respawned; cleanup stopped.'; return 1; }
                    step_log PASS 'No target app processes remain.'
                }

                # Return 0 loaded, 1 explicitly absent, 2 inspection failed. launchctl's other failures
                # (including a deadline or a permission error) cannot establish that a service is absent.
                cleanup_job_state() {
                    local output status=0
                    output=$(bounded_command 5 inspect-service /bin/launchctl print "system/$1" 2>&1) || status=$?
                    [ "$status" != 0 ] || return 0
                    if [ "$status" = 113 ] && [[ "$output" == *"Could not find service \"$1\" in domain for system"* ]]; then
                        return 1
                    fi
                    step_log ERROR "Cannot inspect service $1: $output"
                    return 2
                }

                cleanup_privileged() {
                    local timeout=10
                    case "$1" in /Library/PrivilegedHelperTools/mimo-manage|/Library/PrivilegedHelperTools/com.example.exitipmonitor.manage) timeout=90 ;; esac
                    if [ "$(/usr/bin/id -u)" = 0 ]; then
                        bounded_command "$timeout" remove-provider "$@"
                    else
                        # Only the existing removal grant is used. Never prompt or create a new grant here.
                        bounded_command "$timeout" remove-provider /usr/bin/sudo -n "$@"
                    fi
                }

                cleanup_remember_provider() {
                    local marker
                    if [ "$cleanup_uid" = 0 ]; then
                        marker=/Library/Preferences/com.mimo.legacy-provider-enabled
                    else
                        marker="$HOME/Library/Application Support/Mimo/legacy-provider-enabled"
                        /bin/mkdir -p "$(dirname "$marker")" || return 1
                    fi
                    /usr/bin/touch "$marker"
                }

                cleanup_unload_job() {
                    local label=$1 state=0 ticks=0 started=$SECONDS
                    cleanup_job_state "$label" || state=$?
                    [ "$state" != 2 ] || return 1
                    [ "$state" = 0 ] || return 0
                    cleanup_privileged /bin/launchctl bootout "system/$label" || true
                    while [ "$ticks" -lt 100 ] && [ "$((SECONDS - started))" -lt 20 ]; do
                        state=0; cleanup_job_state "$label" || state=$?
                        [ "$state" != 1 ] || return 0
                        [ "$state" != 2 ] || return 1
                        cleanup_pause
                        ticks=$((ticks + 1))
                    done
                    step_log ERROR "Provider service $label remains loaded."
                    return 1
                }

                cleanup_workers_absent() {
                    local table pid command
                    table=$(cleanup_command_table) || return 2
                    [ -n "$table" ] || return 2
                    while read -r pid command; do
                        case "$command" in
                            "/bin/bash $cleanup_support/tailscale-verge.sh monitor"*|"/bin/bash $cleanup_support/tailscale-verge.sh http"*)
                                step_log WAIT "Provider worker $pid is still exiting."
                                return 1 ;;
                        esac
                    done <<< "$table"
                }

                cleanup_remove_provider() {
                    local path state ticks=0 started
                    cleanup_unload_job "$cleanup_label-http" && cleanup_unload_job "$cleanup_label" || return 1
                    started=$SECONDS
                    while true; do
                        state=0; cleanup_workers_absent || state=$?
                        [ "$state" != 2 ] || { step_log ERROR 'Cannot inspect provider workers.'; return 1; }
                        [ "$state" != 0 ] || break
                        [ "$ticks" -lt 50 ] && [ "$((SECONDS - started))" -lt 10 ] || {
                            step_log ERROR 'Provider workers did not exit.'; return 1;
                        }
                        cleanup_pause
                        ticks=$((ticks + 1))
                    done
                    for path in "$cleanup_http_plist" "$cleanup_plist"; do
                        if cleanup_exists "$path"; then cleanup_privileged /bin/rm -f "$path" || return 1; fi
                    done
                    if cleanup_exists "$cleanup_support"; then
                        cleanup_privileged /bin/rm -rf "$cleanup_support" || return 1
                    fi
                    for path in "$cleanup_http_plist" "$cleanup_plist" "$cleanup_support"; do
                        if cleanup_exists "$path"; then step_log ERROR "Provider component remains: $path"; return 1; fi
                    done
                    # Verify again before deleting the grant, while recovery is still possible.
                    for path in "$cleanup_label-http" "$cleanup_label"; do
                        state=0; cleanup_job_state "$path" || state=$?
                        [ "$state" = 1 ] || { step_log ERROR "Provider service removal not verified: $path"; return 1; }
                    done
                    cleanup_workers_absent || return 1
                    if cleanup_exists "$cleanup_grant"; then cleanup_privileged /bin/rm -f "$cleanup_grant" || return 1; fi
                    if cleanup_exists "$cleanup_grant"; then step_log ERROR 'Removal grant remains.'; return 1; fi
                    step_log PASS 'Both provider services, workers, files and removal grant are absent.'
                }

                cleanup_main() (
                    set -uo pipefail
                    cleanup_app=""
                    while [ "$#" -gt 0 ]; do
                        case "$1" in
                            --app) [ "$#" -ge 2 ] || return 2; cleanup_app=$2; shift 2 ;;
                            --help|-h) sed -n '2,6p' "${BASH_SOURCE[0]}"; return 0 ;;
                            *) echo "Unknown argument: $1" >&2; return 2 ;;
                        esac
                    done
                    case "$cleanup_app" in /*/Mimo.app|/*/ExitIPMonitor.app) ;; *) echo 'Use --app with an absolute Mimo.app path.' >&2; return 2 ;; esac
                    # Retain the lexical absolute path if an old uninstaller already removed the bundle.
                    if [ -d "$cleanup_app" ]; then cleanup_app=$(cd "$cleanup_app" && pwd -P) || return 1; fi
                    cleanup_uid=$(/usr/bin/id -u)
                    cleanup_translocations=""; cleanup_matches=()
                    cleanup_label=com.example.exitipmonitor.tailscale-verge
                    cleanup_plist="/Library/LaunchDaemons/$cleanup_label.plist"
                    cleanup_http_plist="/Library/LaunchDaemons/$cleanup_label-http.plist"
                    cleanup_support='/Library/Application Support/ExitIPMonitor'
                    cleanup_grant=/etc/sudoers.d/exitipmonitor-tailscale-verge
                    step_log BEGIN "Clean uninstall preparation: $cleanup_app"
                    local manager=/Library/PrivilegedHelperTools/mimo-manage
                    if [ ! -f "$manager" ] && [ -f /Library/PrivilegedHelperTools/com.example.exitipmonitor.manage ]; then
                        manager=/Library/PrivilegedHelperTools/com.example.exitipmonitor.manage
                    fi
                    if [ -f "$manager" ]; then
                        # The installed root-owned manager covers every user and preserves machine data.
                        cleanup_privileged "$manager" uninstall || {
                            step_log ERROR "Service cleanup failed. Run sudo '$manager' uninstall, then retry."
                            return 1
                        }
                        cleanup_stop_app || return 1
                        step_log PASS 'Machine service and all installed clients stopped; shared data retained.'
                        return 0
                    fi
                    if [ -d '/Library/Application Support/Mimo/Service' ] || [ -d "$cleanup_support/Service" ]; then
                        local service state
                        for service in com.mimo.core com.mimo.supervisor com.mimo.mihomo com.mimo.pf-boot com.mimo.infrastructure com.example.exitipmonitor.daemon com.example.exitipmonitor.supervisor com.example.exitipmonitor.mihomo; do
                            state=0; cleanup_job_state "$service" || state=$?
                            if [ "$state" != 1 ] || [ -e "/Library/LaunchDaemons/$service.plist" ]; then
                                step_log ERROR 'Service manager is missing but startup components remain. Repair Mimo before uninstalling.'
                                return 1
                            fi
                        done
                        if [ -e /Library/PrivilegedHelperTools/mimo-core ] || [ -e /Library/PrivilegedHelperTools/MimoUninstaller.app ] || [ -e /Library/PrivilegedHelperTools/com.example.exitipmonitor.daemon ]; then
                            step_log ERROR 'Service manager is missing but installed helpers remain. Repair Mimo before uninstalling.'
                            return 1
                        fi
                        cleanup_stop_app || return 1
                        step_log PASS 'Service already removed; retained machine data is ready for reinstall.'
                        return 0
                    fi
                    cleanup_stop_app || return 1
                    if cleanup_exists "$cleanup_plist" || cleanup_exists "$cleanup_http_plist"; then cleanup_remember_provider || return 1; fi
                    cleanup_remove_provider || {
                        step_log ERROR "Provider cleanup failed; the app must not be removed or replaced. Use the existing daemon.sh remove command with administrator authentication, then retry."
                        return 1
                    }
                    # A launch request during service teardown must not escape the final check.
                    cleanup_find_processes || return 1
                    [ "${#cleanup_matches[@]}" = 0 ] || { step_log ERROR 'App restarted during cleanup; retry before replacement.'; return 1; }
                    step_log PASS 'Clean uninstall preparation complete; the app can now be removed.'
                )

                if [[ "${BASH_SOURCE[0]:-}" = "$0" ]]; then cleanup_main "$@"; exit $?; fi

                cleanup_main --app "$1"
                # END GENERATED CLEANUP
              SH
            }

  # Zap removes this account's preferences, profile files and logs. Machine state and
  # System Keychain credentials remain. Retire containers from earlier sandboxed releases too.
  zap trash: [
    "~/Library/Application Support/Mimo",
    "~/Library/Containers/com.mimo",
    "~/Library/Containers/com.mimo.widgets",
    "~/Library/Group Containers/group.com.mimo",
    "~/Library/Preferences/com.mimo.plist",
    "~/Library/Preferences/group.com.mimo.plist",
  ]

  caveats <<~EOS
    Mimo 1.0 supports Apple silicon Macs and IPv4 traffic. Rule and Global
    require a configured proxy and a verified exit IP on the saved allowlist.
    See the release notes for protection boundaries and tested environments.

    Installation requires administrator authentication, installs pinned mihomo
    1.19.34, and disables IPv6 on network services while Mimo is installed.
    Direct uses unproxied IPv4. Uninstall restores the saved IPv6 enabled flags.
    If setup is cancelled, use Install Service or Repair Service in the app.

    The app is ad-hoc signed, not notarized. This cask verifies its sealed signature
    and removes quarantine from this app only. The app is named Mimo.app.
    Existing settings and Keychain entries are migrated to the Mimo identity.
    Open it with:
      open "#{appdir}/Mimo.app"
    Verify startup with:
      /bin/bash "#{appdir}/Mimo.app/Contents/Resources/diagnose-launch.sh" --launch

    Uninstall stops Mimo-owned services, removes the staged mihomo engine and
    generated runtime profiles/caches, login items and private runtime group,
    and restores networking. Saved settings and
    Keychain credentials remain. Homebrew removes an unused mihomo dependency;
    explicitly installed mihomo remains until separately uninstalled.
    The legacy exit-ip-monitor cask must be uninstalled before installing Mimo.
    Release notes: https://github.com/jxz345/mimo/releases/tag/v#{version}
  EOS
end
