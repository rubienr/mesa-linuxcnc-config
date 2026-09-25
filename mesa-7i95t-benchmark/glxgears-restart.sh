#!/usr/bin/env bash
set -euo pipefail
umask 077

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
glxgears_cpuset="${GLXGEARS_CPUSET:-0-1,3-4,6-7,9-10}"
glxgears_instances="${GLXGEARS_INSTANCES:-10}"
glxgears_nice="${GLXGEARS_NICE:-5}"
service_unit="${GLXGEARS_SERVICE_UNIT:-mesa-glxgears-stress}"
stop_timeout="${GLXGEARS_STOP_TIMEOUT:-10}"
shim_source="$script_directory/glxgears-affinity-shim.c"
shim_directory="$script_directory/diagnostic-logs"
shim_library="$shim_directory/.glxgears-affinity-shim.so"
shim_temporary=""

for command_name in bash cc glxgears nice pgrep pkill systemctl systemd-run; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$command_name" >&2
        exit 1
    fi
done

if [[ ! -r $shim_source ]]; then
    printf 'Missing affinity shim source: %s\n' "$shim_source" >&2
    exit 1
fi

if [[ ! $glxgears_instances =~ ^[1-9][0-9]*$ ]]; then
    printf 'GLXGEARS_INSTANCES must be a positive integer.\n' >&2
    exit 2
fi
if [[ ! $glxgears_nice =~ ^-?[0-9]+$ ]] ||
    (( glxgears_nice < -20 || glxgears_nice > 19 )); then
    printf 'GLXGEARS_NICE must be an integer from -20 through 19.\n' >&2
    exit 2
fi
if [[ ! $stop_timeout =~ ^[1-9][0-9]*$ ]]; then
    printf 'GLXGEARS_STOP_TIMEOUT must be a positive integer.\n' >&2
    exit 2
fi
if [[ ! $service_unit =~ ^[A-Za-z0-9_.@-]+$ ]]; then
    printf 'GLXGEARS_SERVICE_UNIT contains unsupported characters.\n' >&2
    exit 2
fi

service_unit="${service_unit%.service}"
service_name="${service_unit}.service"

cleanup_temporary() {
    if [[ -n $shim_temporary && -f $shim_temporary ]]; then
        rm -f -- "$shim_temporary"
    fi
}
trap cleanup_temporary EXIT

mkdir -p -- "$shim_directory"
chmod 0700 -- "$shim_directory"
if [[ ! -f $shim_library || $shim_source -nt $shim_library ]]; then
    shim_temporary=$(mktemp "$shim_directory/.glxgears-affinity-shim.XXXXXX")
    cc -O2 -Wall -Wextra -Werror -fPIC -shared \
        -o "$shim_temporary" "$shim_source" -ldl
    chmod 0700 -- "$shim_temporary"
    mv -f -- "$shim_temporary" "$shim_library"
    shim_temporary=""
fi

printf 'Stopping existing glxgears processes with SIGTERM.\n'
pkill -TERM -x glxgears 2>/dev/null || true

deadline=$((SECONDS + stop_timeout))
while pgrep -x glxgears >/dev/null 2>&1; do
    if (( SECONDS >= deadline )); then
        printf 'Timed out waiting for glxgears to stop; no stronger signal was sent.\n' >&2
        pgrep -a -x glxgears >&2 || true
        exit 3
    fi
    sleep 0.1
done

while systemctl --user is-active --quiet "$service_name"; do
    if (( SECONDS >= deadline )); then
        printf 'Timed out waiting for user service %s to stop.\n' \
            "$service_name" >&2
        exit 4
    fi
    sleep 0.1
done

systemd_environment=()
for variable_name in \
    DISPLAY WAYLAND_DISPLAY XAUTHORITY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS \
    LIBGL_ALWAYS_SOFTWARE DRI_PRIME; do
    if [[ -n ${!variable_name:-} ]]; then
        systemd_environment+=(--setenv="${variable_name}=${!variable_name}")
    fi
done

printf 'Starting %s glxgears instances in %s.\n' \
    "$glxgears_instances" "$service_name"
printf 'Enforced CPUs: %s; nice level: %s\n' \
    "$glxgears_cpuset" "$glxgears_nice"

systemd_environment+=(--setenv="LD_PRELOAD=$shim_library")

trap - EXIT
exec systemd-run --user --wait --pipe --collect \
    --unit="$service_unit" \
    --property="CPUAffinity=$glxgears_cpuset" \
    "${systemd_environment[@]}" \
    bash -c '
        set -euo pipefail
        instance_count=$1
        nice_level=$2

        for ((instance = 1; instance <= instance_count; instance++)); do
            nice -n "$nice_level" glxgears &
        done
        wait
    ' bash "$glxgears_instances" "$glxgears_nice"
