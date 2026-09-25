#!/usr/bin/env bash
set -euo pipefail

repository_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

if (( $# != 1 )); then
    printf 'Usage: %s /path/to/config.ini\n' "${0##*/}" >&2
    printf 'An explicit INI is required to avoid starting the wrong configuration.\n' >&2
    exit 2
fi

exec "$repository_directory/config/linuxcnc-start.sh" "$@"
