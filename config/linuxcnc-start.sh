#!/usr/bin/env bash
set -euo pipefail

servo_cpu="${SERVO_CPU:-11}"

if (( $# != 1 )); then
    printf 'Usage: %s /path/to/config.ini\n' "${0##*/}" >&2
    printf 'An explicit INI is required to avoid starting a benchmark on a connected machine.\n' >&2
    exit 2
fi

ini_file=$1
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-0}"
export RTAPI_CPU_NUMBER="${RTAPI_CPU_NUMBER:-$servo_cpu}"

if [[ ! $RTAPI_CPU_NUMBER =~ ^[0-9]+$ ]]; then
    printf 'RTAPI_CPU_NUMBER must be a nonnegative integer CPU number.\n' >&2
    exit 2
fi

if [[ ! -f "$ini_file" ]]; then
    printf 'LinuxCNC INI file not found: %s\n' "$ini_file" >&2
    exit 1
fi

if [[ -r /etc/profile.d/linuxcnc.sh ]]; then
    TCLLIBPATH=${TCLLIBPATH:-}
    # shellcheck source=/etc/profile.d/linuxcnc.sh
    # The profile fragment returns 1 when the path is already present; that is
    # harmless but must not trip this script's `set -e`.
    source /etc/profile.d/linuxcnc.sh || true
fi

case "$LIBGL_ALWAYS_SOFTWARE" in
    0)
        rendering_label='hardware (LIBGL_ALWAYS_SOFTWARE=0)'
        ;;
    1)
        rendering_label='software (LIBGL_ALWAYS_SOFTWARE=1)'
        ;;
    *)
        printf 'LIBGL_ALWAYS_SOFTWARE must be 0 or 1.\n' >&2
        exit 2
        ;;
esac

printf 'INI: %s\nRendering: %s\nRTAPI realtime CPU: %s\n' \
    "$ini_file" "$rendering_label" "$RTAPI_CPU_NUMBER"

exec linuxcnc "$ini_file"
