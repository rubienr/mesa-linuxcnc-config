#!/usr/bin/env bash
set -euo pipefail

repository_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
exec sudo -- "$repository_directory/config/thread-affinity-set.sh" "$@"
