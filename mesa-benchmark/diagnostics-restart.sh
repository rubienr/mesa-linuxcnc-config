#!/usr/bin/env bash
set -euo pipefail

umask 077

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
log_directory="$script_directory/diagnostic-logs"
monitor="$script_directory/diagnostics-monitor.sh"
stop_helper="$script_directory/diagnostics-stop.sh"
stop_timeout="${MESA_MONITOR_STOP_TIMEOUT:-30}"
start_timeout="${MESA_MONITOR_START_TIMEOUT:-10}"
monitor_arguments=()

usage() {
    cat <<'EOF'
Usage: ./diagnostics-restart.sh [--stop-timeout SECONDS] [--] [MONITOR_OPTIONS]

Gracefully stop the current diagnostic monitor, archive diagnostic-logs with a
UTC timestamp, create a fresh private log directory, and start
diagnostics-monitor.sh under nohup. Remaining arguments are passed to the
monitor. LinuxCNC, HAL, network settings, and machine outputs are not changed.

Options:
  --stop-timeout SECONDS  Graceful shutdown deadline (default: 30)
  -h, --help              Show this help

Environment override:
  MESA_MONITOR_START_TIMEOUT  Startup verification deadline (default: 10)
EOF
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

while (( $# > 0 )); do
    case $1 in
        --stop-timeout)
            (( $# >= 2 )) || die "--stop-timeout requires seconds"
            stop_timeout=$2
            shift 2
            ;;
        --)
            shift
            monitor_arguments+=("$@")
            break
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            monitor_arguments+=("$1")
            shift
            ;;
    esac
done

[[ $stop_timeout =~ ^[1-9][0-9]*$ ]] || die "stop timeout must be a positive integer"
[[ $start_timeout =~ ^[1-9][0-9]*$ ]] || die "start timeout must be a positive integer"

for command_name in chmod cp date mkdir mv nohup sleep tail; do
    command -v "$command_name" >/dev/null 2>&1 ||
        die "missing required command: $command_name"
done
[[ -x $monitor ]] || die "monitor is not executable: $monitor"
[[ -x $stop_helper ]] || die "stop helper is not executable: $stop_helper"

"$stop_helper" --timeout "$stop_timeout"

timestamp=$(date --utc '+%Y%m%dT%H%M%S.%NZ')
archive_directory="$script_directory/diagnostic-logs-$timestamp"
if [[ -e $archive_directory ]]; then
    die "archive path already exists: $archive_directory"
fi

if [[ -d $log_directory ]]; then
    mv -- "$log_directory" "$archive_directory"
    printf 'Archived diagnostics to %s\n' "$archive_directory"
fi

mkdir -m 0700 -- "$log_directory"
if [[ -n ${archive_directory:-} && -d $archive_directory ]]; then
    for tracked_file in .gitignore .keep; do
        if [[ -f $archive_directory/$tracked_file ]]; then
            cp -p -- "$archive_directory/$tracked_file" "$log_directory/$tracked_file"
        fi
    done
fi

console_log="$log_directory/monitor-console.log"
nohup "$monitor" "${monitor_arguments[@]}" >"$console_log" 2>&1 &
monitor_pid=$!

deadline=$((SECONDS + start_timeout))
while (( SECONDS < deadline )); do
    if [[ -r $log_directory/.monitor.lock ]]; then
        IFS= read -r locked_pid <"$log_directory/.monitor.lock" || true
        if [[ $locked_pid == "$monitor_pid" ]]; then
            printf 'Started Mesa diagnostic monitor PID %s.\n' "$monitor_pid"
            printf 'Console log: %s\n' "$console_log"
            exit 0
        fi
    fi
    if ! kill -0 "$monitor_pid" 2>/dev/null; then
        printf 'ERROR: diagnostic monitor exited during startup.\n' >&2
        if [[ -r $console_log ]]; then
            tail -n 40 -- "$console_log" >&2 || true
        fi
        exit 1
    fi
    sleep 0.1
done

printf 'ERROR: diagnostic monitor PID %s did not establish its lock within %s seconds.\n' \
    "$monitor_pid" "$start_timeout" >&2
printf 'The process was not killed; inspect %s.\n' "$console_log" >&2
exit 1
