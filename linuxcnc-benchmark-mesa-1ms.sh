#!/usr/bin/env bash
set -euo pipefail

repository_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
launcher="$repository_directory/config/linuxcnc-start.sh"
affinity_setter="$repository_directory/config/thread-affinity-set.sh"
affinity_checker="$repository_directory/config/thread-affinity-check.sh"
log_directory="$repository_directory/mesa-benchmark/diagnostic-logs"
ini_file="$repository_directory/mesa-benchmark/mesa-7i95t-bench-1ms.ini"
session_name="${MESA_SCREEN_SESSION:-mesa-benchmark-1ms}"
servo_cpu="${SERVO_CPU:-11}"
check_timeout="${LINUXCNC_AFFINITY_CHECK_TIMEOUT:-30}"

if (( $# != 0 )); then
    printf 'Usage: %s\n' "${0##*/}" >&2
    exit 2
fi

[[ $check_timeout =~ ^[1-9][0-9]*$ ]] || {
    printf 'LINUXCNC_AFFINITY_CHECK_TIMEOUT must be a positive integer.\n' >&2
    exit 2
}

for command_name in chmod date grep mkdir nohup pgrep screen sudo tee; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$command_name" >&2
        exit 1
    fi
done

for process_name in linuxcnc linuxcncsvr rtapi_app; do
    if pgrep -x "$process_name" >/dev/null 2>&1; then
        printf 'Refusing to start: an existing %s process is active.\n' \
            "$process_name" >&2
        exit 3
    fi
done

if screen -list 2>/dev/null | grep -F ".${session_name}" >/dev/null 2>&1; then
    printf 'Refusing to start: screen session %s already exists.\n' \
        "$session_name" >&2
    exit 3
fi

umask 077
mkdir -p -- "$log_directory"
chmod 0700 -- "$log_directory"
timestamp=$(date --utc '+%Y%m%dT%H%M%S.%NZ')
affinity_log="$log_directory/thread-affinity-$timestamp.log"

{
    printf 'LinuxCNC Mesa benchmark affinity startup log\n'
    printf 'timestamp_utc: %s\n' "$timestamp"
    printf 'ini: %s\n' "$ini_file"
    printf 'rtapi_cpu_number: %s\n' "$servo_cpu"
    printf '\nprestart_setter:\n'
} | tee "$affinity_log"
sudo "$affinity_setter" 2>&1 | tee -a "$affinity_log"
printf '\nprestart_check:\n' | tee -a "$affinity_log"
if "$affinity_checker" 2>&1 | tee -a "$affinity_log"; then
    :
else
    prestart_check_status=$?
    printf '%s\n' \
        "WARN: pre-start affinity check exited with status $prestart_check_status; continuing because LinuxCNC realtime-task affinity is checked after startup." \
        | tee -a "$affinity_log" >&2
fi

screen -DmS "$session_name" env RTAPI_CPU_NUMBER="$servo_cpu" \
    "$launcher" "$ini_file"
printf '\npoststart_check:\n' >>"$affinity_log"
nohup "$affinity_checker" --wait-for-rt "$check_timeout" \
    >>"$affinity_log" 2>&1 &
printf 'Started Mesa 1 ms benchmark in detached screen session %s.\n' \
    "$session_name"
printf 'Attach with: screen -r %s\n' "$session_name"
printf 'Affinity log: %s\n' "$affinity_log"
