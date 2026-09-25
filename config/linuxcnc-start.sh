#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if (( $# != 1 )); then
    printf 'Usage: %s /path/to/config.ini\n' "${0##*/}" >&2
    printf 'An explicit INI is required to avoid starting a benchmark on a connected machine.\n' >&2
    exit 2
fi

ini_file=$1
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-0}"

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

printf 'INI: %s\nRendering: %s\n' "$ini_file" "$rendering_label"
printf 'After AXIS opens, run sudo %s/thread-affinity-set.sh\n' "$script_dir"

exec linuxcnc "$ini_file"
