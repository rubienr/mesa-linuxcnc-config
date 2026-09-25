#!/usr/bin/env bash
set -euo pipefail

repository_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
config_directory="$repository_directory/config"
log_directory="$repository_directory/mesa-benchmark/diagnostic-logs"
affinity_setter="$config_directory/thread-affinity-set.sh"
affinity_checker="$config_directory/thread-affinity-check.sh"
launcher="$config_directory/linuxcnc-start.sh"
servo_cpu="${SERVO_CPU:-11}"
check_timeout="${LINUXCNC_AFFINITY_CHECK_TIMEOUT:-30}"

if (( $# != 1 )); then
    printf 'Usage: %s /path/to/config.ini\n' "${0##*/}" >&2
    printf 'An explicit INI is required to avoid starting the wrong configuration.\n' >&2
    exit 2
fi

[[ $check_timeout =~ ^[1-9][0-9]*$ ]] || {
    printf 'LINUXCNC_AFFINITY_CHECK_TIMEOUT must be a positive integer.\n' >&2
    exit 2
}

for command_name in chmod date mkdir pgrep sudo tee; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'Missing required command: %s\n' "$command_name" >&2
        exit 1
    }
done

for process_name in linuxcnc linuxcncsvr rtapi_app; do
    if pgrep -x "$process_name" >/dev/null 2>&1; then
        printf 'Refusing to start: an existing %s process is active.\n' \
            "$process_name" >&2
        exit 3
    fi
done

umask 077
mkdir -p -- "$log_directory"
chmod 0700 -- "$log_directory"
timestamp=$(date --utc '+%Y%m%dT%H%M%S.%NZ')
affinity_log="$log_directory/thread-affinity-$timestamp.log"

{
    printf 'LinuxCNC affinity startup log\n'
    printf 'timestamp_utc: %s\n' "$timestamp"
    printf 'ini: %s\n' "$1"
    printf 'rtapi_cpu_number: %s\n' "$servo_cpu"
    printf '\nprestart_setter:\n'
} | tee "$affinity_log"

sudo "$affinity_setter" 2>&1 | tee -a "$affinity_log"
printf '\nprestart_check:\n' | tee -a "$affinity_log"
"$affinity_checker" 2>&1 | tee -a "$affinity_log"

(
    printf '\npoststart_check:\n'
    "$affinity_checker" --wait-for-rt "$check_timeout"
) 2>&1 | tee -a "$affinity_log" &

printf 'Affinity log: %s\n' "$affinity_log"
export RTAPI_CPU_NUMBER="$servo_cpu"
exec "$launcher" "$1"
