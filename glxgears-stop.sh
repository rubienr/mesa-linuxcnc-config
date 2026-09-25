#!/usr/bin/env bash
set -euo pipefail

repository_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
exec "$repository_directory/mesa-benchmark/glxgears-stop.sh" "$@"
