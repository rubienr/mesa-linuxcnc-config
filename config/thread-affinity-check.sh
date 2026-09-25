#!/usr/bin/env bash
set -uo pipefail

lan_interface="${LAN_INTERFACE:-enp1s0}"
wifi_interface="${WIFI_INTERFACE:-wlp2s0}"
lan_irq_cpu="${LAN_IRQ_CPU:-8}"
servo_cpu="${SERVO_CPU:-11}"
protected_cpus=(2 5 8 11)
failures=0
warnings=0
brief=false
wait_for_rt=0

usage() {
    cat <<'EOF'
Usage: ./thread-affinity-check.sh [--brief] [--wait-for-rt SECONDS]

Check kernel isolation, network IRQ placement, and any active LinuxCNC RT task.
--wait-for-rt waits up to SECONDS for the RT task before collecting the checks.
EOF
}

while (( $# > 0 )); do
    case $1 in
        --brief)
            brief=true
            shift
            ;;
        --wait-for-rt)
            (( $# >= 2 )) || { usage >&2; exit 2; }
            wait_for_rt=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
done

[[ $wait_for_rt =~ ^[0-9]+$ ]] || {
    printf 'Wait timeout must be a nonnegative integer.\n' >&2
    exit 2
}

pass() { $brief || printf 'PASS: %s\n' "$*"; }
warn() { ((warnings += 1)); $brief || printf 'WARN: %s\n' "$*"; }
fail() { ((failures += 1)); $brief || printf 'FAIL: %s\n' "$*" >&2; }

rt_task_exists() {
    ps -eLo cls=,comm= | awk '$1 == "FF" && $2 ~ /^rtapi_app:T#/ {found=1} END {exit !found}'
}

if (( wait_for_rt > 0 )); then
    deadline=$((SECONDS + wait_for_rt))
    while ! rt_task_exists && (( SECONDS < deadline )); do
        sleep 0.1
    done
fi

interface_irqs() {
    local interface=$1
    local irq_directory="/sys/class/net/$interface/device/msi_irqs"

    [[ -d "$irq_directory" ]] || return 0
    find "$irq_directory" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort -n
}

irq_description() {
    local irq=$1

    awk -v irq="$irq:" '
        $1 == irq { print $NF; found=1; exit }
        END { if (!found) print "unavailable" }
    ' /proc/interrupts
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

cmdline=$(</proc/cmdline)
for parameter in \
    'isolcpus=domain,managed_irq,5,11' \
    'nohz_full=5,11' \
    'rcu_nocbs=5,11' \
    'irqaffinity=0-4,6-10'; do
    if [[ " $cmdline " == *" $parameter "* ]]; then
        pass "kernel parameter $parameter"
    else
        fail "missing kernel parameter $parameter"
    fi
done

mapfile -t lan_irqs < <(interface_irqs "$lan_interface")
if (( ${#lan_irqs[@]} == 0 )); then
    fail "no MSI IRQs found for LAN interface $lan_interface"
else
    for irq in "${lan_irqs[@]}"; do
        description=$(irq_description "$irq")
        requested=$(<"/proc/irq/$irq/smp_affinity_list")
        effective=$(<"/proc/irq/$irq/effective_affinity_list")
        if [[ "$effective" == "$lan_irq_cpu" ]]; then
            pass "$lan_interface IRQ $irq description=$description requested=$requested effective=$effective"
        else
            fail "$lan_interface IRQ $irq description=$description requested=$requested effective=$effective; expected CPU $lan_irq_cpu"
        fi
    done
fi

mapfile -t wifi_irqs < <(interface_irqs "$wifi_interface")
if (( ${#wifi_irqs[@]} == 0 )); then
    warn "no MSI IRQs found for Wi-Fi interface $wifi_interface"
else
    for irq in "${wifi_irqs[@]}"; do
        description=$(irq_description "$irq")
        requested=$(<"/proc/irq/$irq/smp_affinity_list")
        effective=$(<"/proc/irq/$irq/effective_affinity_list")
        conflict=''
        for protected_cpu in "${protected_cpus[@]}"; do
            if cpulist_contains "$effective" "$protected_cpu"; then
                conflict=$protected_cpu
                break
            fi
        done
        if [[ -n "$conflict" ]]; then
            fail "$wifi_interface IRQ $irq description=$description requested=$requested effective=$effective uses protected CPU $conflict"
        else
            pass "$wifi_interface IRQ $irq description=$description requested=$requested effective=$effective"
        fi
    done
fi

rt_count=0
while read -r tid scheduler rtprio processor command_name; do
    [[ "$scheduler" == FF ]] || continue
    [[ "$command_name" == rtapi_app:T#* ]] || continue
    ((rt_count += 1))
    allowed=$(awk '/^Cpus_allowed_list:/ { print $2 }' "/proc/$tid/status")
    if [[ "$allowed" == "$servo_cpu" ]]; then
        pass "LinuxCNC RT task $tid priority=$rtprio current_cpu=$processor allowed=$allowed"
    else
        fail "LinuxCNC RT task $tid priority=$rtprio current_cpu=$processor allowed=$allowed; expected CPU $servo_cpu"
    fi
done < <(ps -eLo lwp=,cls=,rtprio=,psr=,comm=)

if (( rt_count == 0 )); then
    warn 'LinuxCNC realtime thread is not running; its affinity was not checked'
fi

if (( failures > 0 )); then
    if $brief; then
        printf 'FAIL: %d affinity check(s) failed; warnings=%d.\n' \
            "$failures" "$warnings" >&2
    else
        printf '\n%d affinity check(s) failed.\n' "$failures" >&2
    fi
    exit 1
fi

if $brief; then
    if (( warnings > 0 )); then
        printf 'WARN: active affinity checks passed with %d warning(s).\n' "$warnings"
    else
        printf 'PASS: all active affinity checks passed.\n'
    fi
else
    printf '\nAll active affinity checks passed.\n'
fi
