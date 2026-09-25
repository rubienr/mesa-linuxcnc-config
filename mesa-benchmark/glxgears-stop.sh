#!/usr/bin/env bash
set -euo pipefail

service_unit="${GLXGEARS_SERVICE_UNIT:-mesa-glxgears-stress}"
stop_timeout="${GLXGEARS_STOP_TIMEOUT:-10}"

if (( $# != 0 )); then
    printf 'Usage: %s\n' "${0##*/}" >&2
    exit 2
fi
[[ $stop_timeout =~ ^[1-9][0-9]*$ ]] || {
    printf 'GLXGEARS_STOP_TIMEOUT must be a positive integer.\n' >&2
    exit 2
}
[[ $service_unit =~ ^[A-Za-z0-9_.@-]+$ ]] || {
    printf 'GLXGEARS_SERVICE_UNIT contains unsupported characters.\n' >&2
    exit 2
}

for command_name in pgrep sleep systemctl; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'Missing required command: %s\n' "$command_name" >&2
        exit 1
    }
done

service_name="${service_unit%.service}.service"
if systemctl --user is-active --quiet "$service_name"; then
    printf 'Stopping managed graphics load %s.\n' "$service_name"
    systemctl --user stop "$service_name"
else
    printf 'Managed graphics load %s is not active.\n' "$service_name"
fi

deadline=$((SECONDS + stop_timeout))
while systemctl --user is-active --quiet "$service_name"; do
    if (( SECONDS >= deadline )); then
        printf 'Timed out waiting for %s to stop.\n' "$service_name" >&2
        exit 3
    fi
    sleep 0.1
done

remaining=$(pgrep -c -x glxgears 2>/dev/null || true)
if (( remaining > 0 )); then
    printf 'WARN: %s glxgears process(es) remain outside the managed service.\n' \
        "$remaining" >&2
    exit 4
fi
printf 'Managed graphics load stopped; no glxgears processes remain.\n'
