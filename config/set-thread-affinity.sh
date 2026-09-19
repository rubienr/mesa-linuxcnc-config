#!/usr/bin/env bash
set -euo pipefail

lan_interface="${LAN_INTERFACE:-enp1s0}"
wifi_interface="${WIFI_INTERFACE:-wlp2s0}"
lan_irq_cpu="${LAN_IRQ_CPU:-8}"
servo_cpu="${SERVO_CPU:-11}"

if (( EUID != 0 )); then
    printf 'Run this script with sudo.\n' >&2
    exit 1
fi

interface_irqs() {
    local interface=$1
    local irq_directory="/sys/class/net/$interface/device/msi_irqs"

    [[ -d "$irq_directory" ]] || return 0
    find "$irq_directory" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort -n
}

cpulist_contains() {
    local cpulist=$1
    local wanted=$2
    local item first last
    local -a items

    IFS=',' read -r -a items <<<"$cpulist"
    for item in "${items[@]}"; do
        if [[ "$item" == *-* ]]; then
            first=${item%-*}
            last=${item#*-}
        else
            first=$item
            last=$item
        fi
        if (( wanted >= first && wanted <= last )); then
            return 0
        fi
    done
    return 1
}

set_irq_cpu() {
    local irq=$1
    local cpu=$2
    local affinity_file="/proc/irq/$irq/smp_affinity_list"

    printf '%s\n' "$cpu" >"$affinity_file"
    printf 'IRQ %-4s requested CPU %-2s effective=%s\n' \
        "$irq" "$cpu" "$(<"/proc/irq/$irq/effective_affinity_list")"
}

mapfile -t lan_irqs < <(interface_irqs "$lan_interface")
if (( ${#lan_irqs[@]} == 0 )); then
    printf 'No MSI IRQs found for LAN interface %s.\n' "$lan_interface" >&2
    exit 1
fi

printf 'Pinning %s IRQs to CPU %s\n' "$lan_interface" "$lan_irq_cpu"
for irq in "${lan_irqs[@]}"; do
    set_irq_cpu "$irq" "$lan_irq_cpu"
done

# Move Wi-Fi only when its effective target touches one of the two reserved
# physical cores. Keep the existing distribution for all other vectors.
declare -A wifi_replacement=(
    [2]=1
    [5]=4
    [8]=7
    [11]=10
)

mapfile -t wifi_irqs < <(interface_irqs "$wifi_interface")
if (( ${#wifi_irqs[@]} == 0 )); then
    printf 'No MSI IRQs found for Wi-Fi interface %s; skipping it.\n' \
        "$wifi_interface"
else
    printf 'Moving %s IRQs away from CPUs 2, 5, 8, and 11 when needed\n' \
        "$wifi_interface"
    for irq in "${wifi_irqs[@]}"; do
        effective=$(<"/proc/irq/$irq/effective_affinity_list")
        for protected_cpu in 2 5 8 11; do
            if cpulist_contains "$effective" "$protected_cpu"; then
                set_irq_cpu "$irq" "${wifi_replacement[$protected_cpu]}"
                break
            fi
        done
    done
fi

# The realtime thread exists only after LinuxCNC starts. Pin every FIFO RTAPI
# task (one for this servo-only benchmark) while leaving the UI unpinned.
rt_count=0
while read -r tid scheduler rtprio command_name; do
    [[ "$scheduler" == FF ]] || continue
    [[ "$command_name" == rtapi_app:T#* ]] || continue
    taskset --pid --cpu-list "$servo_cpu" "$tid" >/dev/null
    printf 'LinuxCNC RT task %-7s priority %-3s -> CPU %s\n' \
        "$tid" "$rtprio" "$servo_cpu"
    ((rt_count += 1))
done < <(ps -eLo lwp=,cls=,rtprio=,comm=)

if (( rt_count == 0 )); then
    printf 'LinuxCNC realtime thread is not running; rerun this script after launch.\n'
fi

