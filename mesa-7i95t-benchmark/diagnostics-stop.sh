#!/usr/bin/env bash
set -euo pipefail

script_directory=$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
    pwd -P
)
lock_file="$script_directory/diagnostic-logs/.monitor.lock"
monitor_path="$script_directory/diagnostics-monitor.sh"
legacy_monitor_path="$script_directory/monitor-diagnostics.sh"
timeout_seconds="${MESA_MONITOR_STOP_TIMEOUT:-30}"

usage() {
    cat <<'EOF'
Usage: ./diagnostics-stop.sh [--timeout SECONDS]

Gracefully stop the Mesa diagnostic monitor. The script verifies the active
instance lock and process command line, sends SIGTERM, and waits for the lock
to be released. It never sends SIGKILL and does not affect LinuxCNC or HAL.

Options:
  --timeout SECONDS  Maximum wait for graceful shutdown (default: 30)
  -h, --help         Show this help

Environment override:
  MESA_MONITOR_STOP_TIMEOUT  Default shutdown timeout in seconds
EOF
}

die_usage() {
    printf 'ERROR: %s\n' "$*" >&2
    usage >&2
    exit 2
}

while (( $# > 0 )); do
    case $1 in
        --timeout)
            (( $# >= 2 )) || die_usage "--timeout requires seconds"
            timeout_seconds=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die_usage "unknown argument: $1"
            ;;
    esac
done

[[ $timeout_seconds =~ ^[1-9][0-9]*$ ]] ||
    die_usage "timeout must be a positive integer"

for command_name in flock kill sleep tr; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'ERROR: missing required command: %s\n' "$command_name" >&2
        exit 1
    fi
done

if [[ ! -e $lock_file ]]; then
    printf 'Mesa diagnostic monitor is not running (no lock file).\n'
    exit 0
fi

exec 9<>"$lock_file"
if flock -n 9; then
    printf 'Mesa diagnostic monitor is not running (lock is not held).\n'
    exit 0
fi

IFS= read -r monitor_pid <"$lock_file" || true
if [[ ! $monitor_pid =~ ^[1-9][0-9]*$ ]]; then
    printf 'ERROR: active monitor lock contains an invalid PID: %q\n' \
        "${monitor_pid:-<empty>}" >&2
    exit 4
fi

if [[ ! -r /proc/$monitor_pid/cmdline ]]; then
    printf 'ERROR: monitor lock is held, but PID %s cannot be inspected.\n' \
        "$monitor_pid" >&2
    exit 4
fi

process_command=$(tr '\0' ' ' <"/proc/$monitor_pid/cmdline")
if [[ $process_command != *"$monitor_path"* &&
    $process_command != *"$legacy_monitor_path"* ]]; then
    printf 'ERROR: refusing to signal PID %s; command does not match %s.\n' \
        "$monitor_pid" "$monitor_path" >&2
    printf 'Observed command: %s\n' "$process_command" >&2
    exit 4
fi

printf 'Requesting graceful shutdown of Mesa diagnostic monitor PID %s...\n' \
    "$monitor_pid"
if ! kill -TERM "$monitor_pid" 2>/dev/null; then
    if flock -n 9; then
        printf 'Mesa diagnostic monitor exited before SIGTERM was delivered.\n'
        exit 0
    fi
    printf 'ERROR: unable to send SIGTERM to monitor PID %s.\n' \
        "$monitor_pid" >&2
    exit 1
fi

deadline=$((SECONDS + timeout_seconds))
while (( SECONDS < deadline )); do
    if flock -n 9; then
        printf 'Mesa diagnostic monitor stopped gracefully.\n'
        exit 0
    fi
    sleep 0.1
done

printf 'ERROR: monitor PID %s did not stop within %s seconds.\n' \
    "$monitor_pid" "$timeout_seconds" >&2
printf 'No additional signal was sent.\n' >&2
exit 1
