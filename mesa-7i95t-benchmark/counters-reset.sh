#!/usr/bin/env bash
set -euo pipefail

hal_prefix="${MESA_MONITOR_HAL_PREFIX:-hm2_7i95.0}"

usage() {
    cat <<'EOF'
Usage: ./counters-reset.sh --timing-maxima

Reset only the writable HostMot2 and servo-thread timing maxima. This mutates
diagnostic state. It never resets packet-error totals, error flags, or safety
state, and it does not start or stop LinuxCNC or HAL.
EOF
}

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    usage
    exit 0
fi
if (( $# != 1 )) || [[ $1 != --timing-maxima ]]; then
    usage >&2
    exit 2
fi

command -v halcmd >/dev/null 2>&1 || {
    printf 'Missing required command: halcmd\n' >&2
    exit 1
}

timing_parameters=(
    "${hal_prefix}.read-request.tmax"
    "${hal_prefix}.read.tmax"
    "${hal_prefix}.write.tmax"
    servo-thread.tmax
)
declare -A before=()

for parameter in "${timing_parameters[@]}"; do
    if ! before[$parameter]=$(halcmd getp "$parameter" 2>&1); then
        printf 'Unable to read %s; no values were reset: %s\n' \
            "$parameter" "${before[$parameter]}" >&2
        exit 1
    fi
done

packet_total=$(halcmd getp "${hal_prefix}.packet-error-total" 2>&1) || {
    printf 'Unable to read packet-error total; no values were reset: %s\n' \
        "$packet_total" >&2
    exit 1
}

printf 'Resetting timing maxima at %s\n' "$(date --iso-8601=ns)"
printf 'Packet-error total remains untouched: %s\n' "$packet_total"
for parameter in "${timing_parameters[@]}"; do
    printf '  before %-38s %s ns\n' "$parameter" "${before[$parameter]}"
done

for parameter in "${timing_parameters[@]}"; do
    if ! output=$(halcmd setp "$parameter" 0 2>&1); then
        printf 'Failed to reset %s: %s\n' "$parameter" "$output" >&2
        exit 1
    fi
done

for parameter in "${timing_parameters[@]}"; do
    after=$(halcmd getp "$parameter")
    printf '  after  %-38s %s ns\n' "$parameter" "$after"
done
