#!/usr/bin/env bash
set -euo pipefail

repository_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
benchmark_directory="$repository_directory/mesa-benchmark"
lock_file="$benchmark_directory/diagnostic-logs/.monitor.lock"
affinity_checker="$repository_directory/config/thread-affinity-check.sh"

if (( $# != 0 )); then
    printf 'Usage: %s\n' "${0##*/}" >&2
    exit 2
fi

for command_name in date head pgrep sed systemctl; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'Missing required command: %s\n' "$command_name" >&2
        exit 1
    }
done

printf 'LinuxCNC runtime overview  %s\n' "$(date --iso-8601=seconds)"

monitor_state=STOPPED
monitor_detail='no active lock'
if [[ -r $lock_file ]]; then
    IFS= read -r monitor_pid <"$lock_file" || true
    if [[ ${monitor_pid:-} =~ ^[1-9][0-9]*$ ]] &&
        kill -0 "$monitor_pid" 2>/dev/null; then
        monitor_state=RUNNING
        monitor_detail="pid=$monitor_pid"
    fi
fi
printf '%-12s %-8s %s\n' monitor "$monitor_state" "$monitor_detail"

linuxcnc_pid=$(pgrep -o -x linuxcnc 2>/dev/null || true)
if [[ -n $linuxcnc_pid ]]; then
    printf '%-12s %-8s pid=%s\n' linuxcnc RUNNING "$linuxcnc_pid"
else
    printf '%-12s %-8s\n' linuxcnc STOPPED
fi

benchmark_process=$(pgrep -a -f 'linuxcnc.*mesa-7i95t-bench-[12]ms.ini' 2>/dev/null | head -n 1 || true)
if [[ -n $benchmark_process ]]; then
    benchmark_profile=$(sed -n 's/.*\(mesa-7i95t-bench-[12]ms\.ini\).*/\1/p' <<<"$benchmark_process")
    printf '%-12s %-8s %s\n' benchmark RUNNING "profile=${benchmark_profile:-unknown}"
else
    printf '%-12s %-8s\n' benchmark STOPPED
fi

glxgears_count=$(pgrep -c -x glxgears 2>/dev/null || true)
glxgears_service=$(systemctl --user is-active mesa-glxgears-stress.service 2>/dev/null || true)
printf '%-12s %-8s service=%s instances=%s\n' glxgears \
    "$([[ $glxgears_count =~ ^[1-9] ]] && printf RUNNING || printf STOPPED)" \
    "${glxgears_service:-unavailable}" "$glxgears_count"

affinity_result=$($affinity_checker --brief 2>&1) || affinity_status=$?
affinity_status=${affinity_status:-0}
printf '%-12s %-8s %s\n' affinity \
    "$([[ $affinity_status == 0 ]] && printf OK || printf FAILED)" \
    "$affinity_result"

exit "$affinity_status"
