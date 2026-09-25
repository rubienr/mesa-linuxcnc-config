#!/usr/bin/env bash
set -euo pipefail

script_directory=$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
    pwd -P
)
workspace_directory=$(cd -- "$script_directory/.." && pwd -P)
target_ssh_destination="${TARGET_SSH_DESTINATION:-frida@frida}"
target_workspace="${TARGET_WORKSPACE:-~/linuxcnc}"
dry_run_args=()

usage() {
    cat <<'EOF'
Usage: ./tools/sync-to-target.sh [--dry-run]

Synchronize this workspace to the LinuxCNC target over SSH. The Git directory
is excluded, and files absent from the local workspace are never deleted from
the target.

Environment overrides:
  TARGET_SSH_DESTINATION  SSH destination (default: frida@frida)
  TARGET_WORKSPACE        Remote workspace (default: ~/linuxcnc)
EOF
}

case "${1:-}" in
    "")
        ;;
    --dry-run)
        dry_run_args+=(--dry-run)
        ;;
    --help|-h)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac

if (( $# > 1 )); then
    usage >&2
    exit 2
fi

printf 'Synchronizing %s/ to %s:%s/\n' \
    "$workspace_directory" "$target_ssh_destination" "${target_workspace%/}"

rsync \
    --archive \
    --human-readable \
    --itemize-changes \
    --verbose \
    --exclude='/.git/' \
    --include='/mesa-benchmark/diagnostic-logs/' \
    --include='/mesa-benchmark/diagnostic-logs/.gitignore' \
    --include='/mesa-benchmark/diagnostic-logs/.keep' \
    --exclude='/mesa-benchmark/diagnostic-logs/***' \
    --exclude='/mesa-benchmark/diagnostic-logs-*/***' \
    "${dry_run_args[@]}" \
    "$workspace_directory/" \
    "$target_ssh_destination:${target_workspace%/}/"
