#!/usr/bin/env bash
set -euo pipefail

script_path=$(readlink -f -- "${BASH_SOURCE[0]}")
interval="${WATCH_INTERVAL:-1}"

print_pin() {
    local label=$1
    local pin=$2
    local suffix=${3:-}
    local value

    if value=$(halcmd getp "$pin" 2>&1); then
        printf '  %-10s %s%s\n' "$label" "$value" "$suffix"
    else
        printf '  %-10s ERROR: %s\n' "$label" "$value"
        return 1
    fi
}

print_snapshot() {
    local result=0
    local servo_thread

    printf 'Mesa 7I95T benchmark counters  %s\n\n' "$(date '+%F %T')"
    printf 'Communication errors\n'
    print_pin total hm2_7i95.0.packet-error-total || result=1
    print_pin level hm2_7i95.0.packet-error-level || result=1
    print_pin packet hm2_7i95.0.packet-error || result=1
    print_pin exceeded hm2_7i95.0.packet-error-exceeded || result=1
    print_pin io_error hm2_7i95.0.io_error || result=1

    printf '\nHostMot2 timing\n'
    print_pin read_tmax hm2_7i95.0.read.tmax ' ns' || result=1
    print_pin write_tmax hm2_7i95.0.write.tmax ' ns' || result=1

    printf '\nServo thread\n'
    if servo_thread=$(halcmd show thread 2>&1); then
        servo_thread=$(printf '%s\n' "$servo_thread" | awk '/servo-thread/')
        if [[ -n "$servo_thread" ]]; then
            printf '%s\n' "$servo_thread"
        else
            printf '  servo-thread not found\n'
            result=1
        fi
    else
        printf '  ERROR: %s\n' "$servo_thread"
        result=1
    fi

    return "$result"
}

if [[ ${1:-} == --once ]]; then
    command -v halcmd >/dev/null 2>&1 || {
        printf 'Missing required command: halcmd\n' >&2
        exit 1
    }
    print_snapshot
    exit
fi

if (( $# != 0 )); then
    printf 'Usage: %s [--once]\n' "${0##*/}" >&2
    exit 2
fi

if [[ ! $interval =~ ^[0-9]+([.][0-9]+)?$ ]] || [[ $interval == 0 ]]; then
    printf 'WATCH_INTERVAL must be a positive number of seconds.\n' >&2
    exit 2
fi

for command_name in watch halcmd readlink awk; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$command_name" >&2
        exit 1
    fi
done

exec watch --interval "$interval" --precise --no-title --exec \
    "$script_path" --once
