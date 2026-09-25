#!/usr/bin/env bash
set -euo pipefail

repository_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
launcher="$repository_directory/config/linuxcnc-start.sh"
ini_file="$repository_directory/mesa-benchmark/mesa-7i95t-bench-1ms.ini"
session_name="${MESA_SCREEN_SESSION:-mesa-benchmark-1ms}"

if (( $# != 0 )); then
    printf 'Usage: %s\n' "${0##*/}" >&2
    exit 2
fi

for command_name in grep pgrep screen; do
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

screen -DmS "$session_name" "$launcher" "$ini_file"
printf 'Started Mesa 1 ms benchmark in detached screen session %s.\n' \
    "$session_name"
printf 'Attach with: screen -r %s\n' "$session_name"
