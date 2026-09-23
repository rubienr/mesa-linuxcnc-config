#!/usr/bin/env bash
set -euo pipefail

umask 077

script_path=$(readlink -f -- "${BASH_SOURCE[0]}")
script_directory=$(dirname -- "$script_path")
log_directory="$script_directory/diagnostic-logs"
default_cpu_list="0-1,3-4,6-7,9-10"

sample_interval="${MESA_MONITOR_INTERVAL:-1}"
heartbeat_interval="${MESA_MONITOR_HEARTBEAT_INTERVAL:-300}"
monitor_cpu_list="${MESA_MONITOR_CPU_LIST:-$default_cpu_list}"
max_log_bytes="${MESA_MONITOR_MAX_LOG_BYTES:-67108864}"
rotated_log_count="${MESA_MONITOR_ROTATED_LOG_COUNT:-5}"
output_name=""
reset_tmax=false
mock_mode=false
max_samples=0

format_version=1
network_interface="${MESA_MONITOR_INTERFACE:-enp1s0}"
wifi_interface="${MESA_MONITOR_WIFI_INTERFACE:-wlp2s0}"
hal_prefix="${MESA_MONITOR_HAL_PREFIX:-hm2_7i95.0}"

declare -A current=()
declare -A baseline=()
declare -A previous=()
declare -A previous_record=()
declare -A observed_peak=()

numeric_keys=(
    packet_total packet_level read_request_tmax_ns read_tmax_ns write_tmax_ns
    servo_period_ns servo_current_ns servo_tmax_ns rx_packets rx_errors
    rx_dropped rx_missed_errors tx_packets tx_errors tx_dropped
    mesa_irq_count wifi_irq_count stress_ng_count glxgears_count
    benchmark_elapsed_s
)
peak_keys=(read_request_tmax_ns read_tmax_ns write_tmax_ns servo_tmax_ns)
change_keys=(
    link_operstate link_carrier link_speed_mbps link_duplex mesa_irq_affinity
    wifi_irq_affinity rt_tid rt_cpu rt_allowed_cpus rt_policy rt_priority
    benchmark_pid stress_ng_count glxgears_count
)
nic_event_keys=(rx_errors rx_dropped rx_missed_errors tx_errors tx_dropped)

record_sequence=0
sample_sequence=0
mock_sequence=0
last_event_sample=0
start_monotonic_ns=0
next_sample_ns=0
next_heartbeat_ns=0
sampling_lateness_ns=0
sample_started_monotonic_ns=0
expected_sample_monotonic_ns=0
collection_error=""
detected_event_types=""
stop_requested=false
stop_reason="completed"
stop_exit_code=0
rebaseline_peaks=false
record_tmp=""
log_file=""
session_id=""

usage() {
    cat <<'EOF'
Usage: ./monitor-diagnostics.sh [OPTIONS]

Append Mesa 7I95T communication and timing events to a diagnostic log. The
monitor is read-only unless --reset-tmax-after-event is explicitly selected.

Options:
  --output NAME                 Log filename within diagnostic-logs/
  --interval SECONDS            Sampling interval (default: 1)
  --heartbeat SECONDS           Rich heartbeat interval (default: 300)
  --max-log-bytes BYTES         Rotate before exceeding this size
  --rotated-logs COUNT          Number of rotated logs to retain
  --reset-tmax-after-event      Reset writable timing maxima after events
  --max-samples COUNT           Stop after COUNT post-baseline samples
  --mock                        Use safe built-in test data; do not access HAL
  -h, --help                    Show this help

Environment overrides:
  MESA_MONITOR_INTERFACE, MESA_MONITOR_WIFI_INTERFACE,
  MESA_MONITOR_HAL_PREFIX, MESA_MONITOR_CPU_LIST

The monitor pins itself and its child commands to MESA_MONITOR_CPU_LIST. The
default excludes CPUs 2, 5, 8, and 11.
EOF
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

is_positive_number() {
    [[ $1 =~ ^[0-9]+([.][0-9]+)?$ ]] && [[ $1 != 0 ]] && [[ $1 != 0.0 ]]
}

is_nonnegative_integer() {
    [[ $1 =~ ^[0-9]+$ ]]
}

while (( $# > 0 )); do
    case $1 in
        --output)
            (( $# >= 2 )) || die "--output requires a filename"
            output_name=$2
            shift 2
            ;;
        --interval)
            (( $# >= 2 )) || die "--interval requires seconds"
            sample_interval=$2
            shift 2
            ;;
        --heartbeat)
            (( $# >= 2 )) || die "--heartbeat requires seconds"
            heartbeat_interval=$2
            shift 2
            ;;
        --max-log-bytes)
            (( $# >= 2 )) || die "--max-log-bytes requires bytes"
            max_log_bytes=$2
            shift 2
            ;;
        --rotated-logs)
            (( $# >= 2 )) || die "--rotated-logs requires a count"
            rotated_log_count=$2
            shift 2
            ;;
        --reset-tmax-after-event)
            reset_tmax=true
            shift
            ;;
        --max-samples)
            (( $# >= 2 )) || die "--max-samples requires a count"
            max_samples=$2
            shift 2
            ;;
        --mock)
            mock_mode=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
done

is_positive_number "$sample_interval" || die "sample interval must be positive"
is_positive_number "$heartbeat_interval" || die "heartbeat interval must be positive"
is_nonnegative_integer "$max_log_bytes" || die "max log bytes must be an integer"
(( max_log_bytes >= 1048576 )) || die "max log bytes must be at least 1048576"
is_nonnegative_integer "$rotated_log_count" || die "rotated log count must be an integer"
(( rotated_log_count >= 1 )) || die "rotated log count must be at least 1"
is_nonnegative_integer "$max_samples" || die "max samples must be an integer"

if [[ -n $output_name ]]; then
    [[ $output_name != */* && $output_name != . && $output_name != .. ]] ||
        die "--output must be a filename, not a path"
    [[ $output_name != .monitor.lock && $output_name != .record.* ]] ||
        die "reserved output filename: $output_name"
fi

required_commands=(awk cat chmod date dirname ethtool find flock grep halcmd head hostname ip mkdir mktemp mv nproc pgrep ps readlink rm sed sha256sum sleep sort stat taskset tr uname)
if $mock_mode; then
    required_commands=(awk cat chmod date dirname flock grep head hostname mkdir mktemp mv nproc ps readlink rm sed sha256sum sleep sort stat taskset tr uname)
fi
for command_name in "${required_commands[@]}"; do
    command -v "$command_name" >/dev/null 2>&1 || die "missing required command: $command_name"
done

if [[ ${MESA_MONITOR_PINNED:-0} != 1 ]]; then
    reexec_args=(
        --interval "$sample_interval"
        --heartbeat "$heartbeat_interval"
        --max-log-bytes "$max_log_bytes"
        --rotated-logs "$rotated_log_count"
        --max-samples "$max_samples"
    )
    [[ -n $output_name ]] && reexec_args+=(--output "$output_name")
    $reset_tmax && reexec_args+=(--reset-tmax-after-event)
    $mock_mode && reexec_args+=(--mock)
    exec taskset --cpu-list "$monitor_cpu_list" env MESA_MONITOR_PINNED=1 \
        "$script_path" "${reexec_args[@]}"
fi

mkdir -p -- "$log_directory"
chmod 0700 -- "$log_directory"

exec 9>>"$log_directory/.monitor.lock"
if ! flock -n 9; then
    printf 'Another Mesa diagnostic monitor holds %s/.monitor.lock\n' "$log_directory" >&2
    exit 3
fi
: >"$log_directory/.monitor.lock"
printf '%s\n' "$$" >&9

wall_timestamp() {
    date --iso-8601=ns
}

monotonic_ns() {
    awk '{printf "%.0f\n", $1 * 1000000000}' /proc/uptime
}

seconds_to_ns() {
    awk -v seconds="$1" 'BEGIN {printf "%.0f\n", seconds * 1000000000}'
}

sample_interval_ns=$(seconds_to_ns "$sample_interval")
heartbeat_interval_ns=$(seconds_to_ns "$heartbeat_interval")
start_monotonic_ns=$(monotonic_ns)
sample_started_monotonic_ns=$start_monotonic_ns
expected_sample_monotonic_ns=$start_monotonic_ns
next_sample_ns=$((start_monotonic_ns + sample_interval_ns))
next_heartbeat_ns=$((start_monotonic_ns + heartbeat_interval_ns))
session_id="$(date --utc '+%Y%m%dT%H%M%S.%NZ')-$$"
if [[ -z $output_name ]]; then
    output_name="mesa-diagnostics-${session_id}.log"
fi
log_file="$log_directory/$output_name"

printf '%s\n' "$$" >"$log_directory/.monitor.lock"
printf 'Mesa diagnostic monitor PID %s; log %s\n' "$$" "$log_file"

cleanup_record_tmp() {
    if [[ -n ${record_tmp:-} && -f $record_tmp ]]; then
        rm -f -- "$record_tmp"
    fi
}
trap cleanup_record_tmp EXIT

request_stop() {
    stop_requested=true
    stop_reason=$1
    stop_exit_code=$2
}
trap 'request_stop SIGINT 130' INT
trap 'request_stop SIGTERM 143' TERM

read_file_or_unknown() {
    local path=$1
    if [[ -r $path ]]; then
        tr -d '\n' <"$path"
    else
        printf 'unknown'
    fi
}

hal_value() {
    local text=$1
    local name=$2
    awk -v wanted="$name" '$NF == wanted {print $(NF - 1); found=1; exit} END {if (!found) exit 1}' <<<"$text"
}

irq_numbers() {
    local interface=$1
    local irq_directory="/sys/class/net/$interface/device/msi_irqs"
    if [[ -d $irq_directory ]]; then
        find "$irq_directory" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | sort -n
    fi
}

irq_affinities() {
    local interface=$1
    local irq
    local result=""
    while IFS= read -r irq; do
        [[ -n $irq ]] || continue
        result+="${result:+,}${irq}:$(read_file_or_unknown "/proc/irq/$irq/effective_affinity_list")"
    done < <(irq_numbers "$interface")
    printf '%s\n' "${result:-none}"
}

irq_count_for_number() {
    local irq=$1
    awk -v wanted="${irq}:" '
            NR == 1 {cpu_columns=NF}
            $1 == wanted {
                sum=0
                for (field=2; field<=cpu_columns+1; field++) sum += $field
                printf "%.0f\n", sum
                found=1
            }
            END {if (!found) print 0}
        ' /proc/interrupts
}

irq_count() {
    local interface=$1
    local irq
    local total=0
    local count
    while IFS= read -r irq; do
        [[ -n $irq ]] || continue
        count=$(irq_count_for_number "$irq")
        total=$((total + count))
    done < <(irq_numbers "$interface")
    printf '%s\n' "$total"
}

process_count() {
    local name=$1
    pgrep -c -x "$name" 2>/dev/null || true
}

collect_real_core() {
    local pins_output params_output thread_output servo_values benchmark_values rt_values

    current=()
    collection_error=""
    if ! pins_output=$(halcmd -s show pin "${hal_prefix}.packet-error*" 2>&1); then
        collection_error="halcmd packet pins failed: $pins_output"
        return 1
    fi
    if ! params_output=$(halcmd -s show param "${hal_prefix}.*tmax" 2>&1); then
        collection_error="halcmd timing parameters failed: $params_output"
        return 1
    fi
    if ! thread_output=$(halcmd -s show thread 2>&1); then
        collection_error="halcmd thread query failed: $thread_output"
        return 1
    fi

    current[packet_total]=$(hal_value "$pins_output" "${hal_prefix}.packet-error-total") || {
        collection_error="packet-error-total missing from HAL output"
        return 1
    }
    current[packet_level]=$(hal_value "$pins_output" "${hal_prefix}.packet-error-level") || return 1
    current[packet_error]=$(hal_value "$pins_output" "${hal_prefix}.packet-error") || return 1
    current[packet_exceeded]=$(hal_value "$pins_output" "${hal_prefix}.packet-error-exceeded") || return 1
    if ! current[io_error]=$(halcmd getp "${hal_prefix}.io_error" 2>&1); then
        collection_error="halcmd io_error failed: ${current[io_error]}"
        return 1
    fi
    current[read_request_tmax_ns]=$(hal_value "$params_output" "${hal_prefix}.read-request.tmax") || return 1
    current[read_tmax_ns]=$(hal_value "$params_output" "${hal_prefix}.read.tmax") || return 1
    current[write_tmax_ns]=$(hal_value "$params_output" "${hal_prefix}.write.tmax") || return 1

    servo_values=$(awk '$3 == "servo-thread" {print $1, $4, $5; found=1; exit} END {if (!found) exit 1}' <<<"$thread_output") || {
        collection_error="servo-thread missing from HAL output"
        return 1
    }
    read -r current[servo_period_ns] current[servo_current_ns] current[servo_tmax_ns] <<<"$servo_values"

    current[rx_packets]=$(read_file_or_unknown "/sys/class/net/$network_interface/statistics/rx_packets")
    current[rx_errors]=$(read_file_or_unknown "/sys/class/net/$network_interface/statistics/rx_errors")
    current[rx_dropped]=$(read_file_or_unknown "/sys/class/net/$network_interface/statistics/rx_dropped")
    current[rx_missed_errors]=$(read_file_or_unknown "/sys/class/net/$network_interface/statistics/rx_missed_errors")
    current[tx_packets]=$(read_file_or_unknown "/sys/class/net/$network_interface/statistics/tx_packets")
    current[tx_errors]=$(read_file_or_unknown "/sys/class/net/$network_interface/statistics/tx_errors")
    current[tx_dropped]=$(read_file_or_unknown "/sys/class/net/$network_interface/statistics/tx_dropped")
    current[link_operstate]=$(read_file_or_unknown "/sys/class/net/$network_interface/operstate")
    current[link_carrier]=$(read_file_or_unknown "/sys/class/net/$network_interface/carrier")
    current[link_speed_mbps]=$(read_file_or_unknown "/sys/class/net/$network_interface/speed")
    current[link_duplex]=$(read_file_or_unknown "/sys/class/net/$network_interface/duplex")
    current[mesa_irq_count]=$(irq_count "$network_interface")
    current[wifi_irq_count]=$(irq_count "$wifi_interface")
    current[mesa_irq_affinity]=$(irq_affinities "$network_interface")
    current[wifi_irq_affinity]=$(irq_affinities "$wifi_interface")

    rt_values=$(ps -eLo tid=,psr=,cls=,rtprio=,comm= |
        awk '$5 == "rtapi_app:T#0" {print $1, $2, $3, $4; exit}')
    if [[ -n $rt_values ]]; then
        read -r current[rt_tid] current[rt_cpu] current[rt_policy] current[rt_priority] <<<"$rt_values"
        current[rt_allowed_cpus]=$(awk '/^Cpus_allowed_list:/ {print $2}' "/proc/${current[rt_tid]}/status")
    else
        current[rt_tid]="none"
        current[rt_cpu]="none"
        current[rt_policy]="none"
        current[rt_priority]="none"
        current[rt_allowed_cpus]="none"
    fi

    benchmark_values=$(ps -eo pid=,etimes=,args= | awk '/[l]inuxcnc .*mesa-7i95t-bench-[12]ms.ini/ {print $1, $2; exit}')
    if [[ -n $benchmark_values ]]; then
        read -r current[benchmark_pid] current[benchmark_elapsed_s] <<<"$benchmark_values"
    else
        current[benchmark_pid]="none"
        current[benchmark_elapsed_s]=0
    fi
    current[stress_ng_count]=$(process_count stress-ng)
    current[glxgears_count]=$(process_count glxgears)
    current[load_average]=$(< /proc/loadavg)
    current[cpu_pressure]=$(tr '\n' ';' < /proc/pressure/cpu)
    current[memory_pressure]=$(tr '\n' ';' < /proc/pressure/memory)
    current[io_pressure]=$(tr '\n' ';' < /proc/pressure/io)
}

collect_mock_core() {
    current=()
    collection_error=""
    current[packet_total]=10
    current[packet_level]=0
    current[packet_error]=FALSE
    current[packet_exceeded]=FALSE
    current[io_error]=FALSE
    current[read_request_tmax_ns]=10000
    current[read_tmax_ns]=700000
    current[write_tmax_ns]=90000
    current[servo_period_ns]=1000000
    current[servo_current_ns]=350000
    current[servo_tmax_ns]=750000
    current[rx_packets]=$((100000 + mock_sequence * 1000))
    current[rx_errors]=0
    current[rx_dropped]=0
    current[rx_missed_errors]=0
    current[tx_packets]=$((200000 + mock_sequence * 2000))
    current[tx_errors]=0
    current[tx_dropped]=0
    current[link_operstate]=up
    current[link_carrier]=1
    current[link_speed_mbps]=100
    current[link_duplex]=full
    current[mesa_irq_count]=$((500000 + mock_sequence * 1000))
    current[wifi_irq_count]=$((250000 + mock_sequence * 10))
    current[mesa_irq_affinity]="63:8"
    current[wifi_irq_affinity]="68:3"
    current[rt_tid]=12345
    current[rt_cpu]=11
    current[rt_policy]=FF
    current[rt_priority]=98
    current[rt_allowed_cpus]=11
    current[benchmark_pid]=12300
    current[benchmark_elapsed_s]=$((3600 + mock_sequence))
    current[stress_ng_count]=0
    current[glxgears_count]=8
    current[load_average]="1.00 1.00 1.00 1/100 12345"
    current[cpu_pressure]="some avg10=0.00 avg60=0.00 avg300=0.00 total=0;"
    current[memory_pressure]="some avg10=0.00 avg60=0.00 avg300=0.00 total=0;"
    current[io_pressure]="some avg10=0.00 avg60=0.00 avg300=0.00 total=0;"

    case $mock_sequence in
        2)
            current[read_tmax_ns]=1200000
            current[servo_tmax_ns]=1250000
            ;;
        3)
            collection_error="mocked halcmd collection failure"
            mock_sequence=$((mock_sequence + 1))
            return 1
            ;;
        4|5)
            current[packet_total]=11
            current[read_tmax_ns]=2500000
            current[servo_tmax_ns]=2550000
            ;;
    esac
    mock_sequence=$((mock_sequence + 1))
}

collect_core() {
    if $mock_mode; then
        collect_mock_core
    else
        collect_real_core
    fi
}

numeric_delta() {
    local value=${1:-unknown}
    local reference=${2:-unknown}
    if [[ $value =~ ^-?[0-9]+$ && $reference =~ ^-?[0-9]+$ ]]; then
        printf '%s\n' "$((value - reference))"
    else
        printf 'unknown\n'
    fi
}

run_section_command() {
    local label=$1
    shift
    local output status
    printf '  section: %s\n' "$label"
    if output=$("$@" 2>&1); then
        status=0
    else
        status=$?
    fi
    printf '  status: %s\n' "$status"
    if [[ -n $output ]]; then
        sed 's/^/    /' <<<"$output"
    else
        printf '    (no output)\n'
    fi
}

write_irq_details() {
    local interface irq
    for interface in "$network_interface" "$wifi_interface"; do
        printf '    interface=%s\n' "$interface"
        while IFS= read -r irq; do
            [[ -n $irq ]] || continue
            printf '    irq=%s requested=%s effective=%s\n' \
                "$irq" \
                "$(read_file_or_unknown "/proc/irq/$irq/smp_affinity_list")" \
                "$(read_file_or_unknown "/proc/irq/$irq/effective_affinity_list")"
            printf '    irq=%s count=%s\n' "$irq" "$(irq_count_for_number "$irq")"
            ps -eLo pid=,tid=,psr=,cls=,rtprio=,pri=,ni=,pcpu=,stat=,comm= |
                awk -v wanted="irq/${irq}-" 'index($NF, wanted) == 1 {$1=$1; print "    thread=" $0}' || true
        done < <(irq_numbers "$interface")
    done
}

write_cpu_details() {
    local cpu item path
    for cpu in 2 5 8 11; do
        printf '    cpu=%s' "$cpu"
        for item in scaling_driver scaling_governor energy_performance_preference scaling_min_freq scaling_max_freq scaling_cur_freq; do
            path="/sys/devices/system/cpu/cpu${cpu}/cpufreq/${item}"
            printf ' %s=%s' "$item" "$(read_file_or_unknown "$path")"
        done
        printf '\n'
    done
}

write_realtime_details() {
    if [[ ${current[rt_tid]:-none} == none ]]; then
        printf '    realtime_task=not_found\n'
        return
    fi
    ps -eLo pid=,tid=,lstart=,etimes=,psr=,cls=,rtprio=,pri=,ni=,pcpu=,stat=,comm=,args= |
        awk -v wanted="${current[rt_tid]}" '$2 == wanted {$1=$1; print "    " $0}' || true
    printf '    allowed_cpus=%s\n' "${current[rt_allowed_cpus]}"
}

write_benchmark_details() {
    if [[ ${current[benchmark_pid]:-none} == none ]]; then
        printf '    benchmark_process=not_found\n'
        return
    fi
    ps -p "${current[benchmark_pid]}" -o pid=,lstart=,etimes=,args= |
        sed 's/^/    /' || true
}

write_rich_snapshot() {
    local journal_since=${1:-"-20 seconds"}
    printf 'snapshot_begin:\n'
    if $mock_mode; then
        printf '  section: mock_environment\n'
        printf '  status: 0\n'
        printf '    Safe mock mode: HAL and network commands were not executed.\n'
        printf 'snapshot_end\n'
        return
    fi

    run_section_command hal_packet_pins halcmd -s show pin "${hal_prefix}.packet-error*"
    run_section_command hal_packet_parameters halcmd -s show param "${hal_prefix}.packet-error*"
    run_section_command hal_timing_parameters halcmd -s show param "${hal_prefix}.*tmax"
    run_section_command hal_threads halcmd -s show thread
    run_section_command ip_link ip -s -details link show dev "$network_interface"
    run_section_command ethtool_statistics ethtool -S "$network_interface"
    run_section_command ethtool_driver ethtool -i "$network_interface"
    run_section_command ethtool_link ethtool "$network_interface"
    run_section_command ethtool_eee ethtool --show-eee "$network_interface"
    run_section_command ethtool_offloads ethtool -k "$network_interface"
    if command -v nstat >/dev/null 2>&1; then
        run_section_command network_protocol_statistics nstat -az
    fi
    printf '  section: irq_details\n'
    printf '  status: 0\n'
    write_irq_details
    printf '  section: realtime_task\n'
    printf '  status: 0\n'
    write_realtime_details
    printf '  section: benchmark_process\n'
    printf '  status: 0\n'
    write_benchmark_details
    run_section_command stress_ng_processes pgrep -a -x stress-ng
    run_section_command glxgears_processes pgrep -a -x glxgears
    run_section_command active_benchmark pgrep -a -f 'linuxcnc.*mesa-7i95t-bench-[12]ms.ini'
    run_section_command kernel_messages journalctl -b -k --since "$journal_since" --no-pager -o short-precise
    printf '  section: cpu_policy\n'
    printf '  status: 0\n'
    write_cpu_details
    printf '  section: host_state\n'
    printf '  status: 0\n'
    printf '    hostname=%s\n' "$(hostname)"
    printf '    boot_id=%s\n' "$(read_file_or_unknown /proc/sys/kernel/random/boot_id)"
    printf '    kernel=%s\n' "$(uname -a)"
    printf '    cmdline=%s\n' "$(read_file_or_unknown /proc/cmdline)"
    printf '    uptime=%s\n' "$(read_file_or_unknown /proc/uptime)"
    printf '    pci_power_control=%s\n' "$(read_file_or_unknown "/sys/class/net/$network_interface/device/power/control")"
    printf '    pci_runtime_status=%s\n' "$(read_file_or_unknown "/sys/class/net/$network_interface/device/power/runtime_status")"
    printf '    pcie_aspm_policy=%s\n' "$(read_file_or_unknown /sys/module/pcie_aspm/parameters/policy)"
    if command -v pacman >/dev/null 2>&1; then
        printf '    linuxcnc_version=%s\n' "$(pacman -Q linuxcnc 2>&1 || printf unknown)"
    else
        printf '    linuxcnc_version=unknown\n'
    fi
    printf '    git_revision=%s\n' "$(git -C "$script_directory" rev-parse HEAD 2>/dev/null || printf unknown)"
    printf '    script_sha256=%s\n' "$(sha256sum "$script_path" | awk '{print $1}')"
    printf 'snapshot_end\n'
}

rotate_log_if_needed() {
    local incoming_size=$1
    local current_size=0
    local index
    if [[ -f $log_file ]]; then
        current_size=$(stat -c %s -- "$log_file")
    fi
    (( current_size + incoming_size <= max_log_bytes )) && return

    for ((index=rotated_log_count-1; index>=1; index--)); do
        if [[ -f ${log_file}.${index} ]]; then
            mv -f -- "${log_file}.${index}" "${log_file}.$((index + 1))"
        fi
    done
    if [[ -f $log_file ]]; then
        mv -f -- "$log_file" "${log_file}.1"
    fi
    {
        printf '# mesa-7i95t-diagnostic-log format_version=%s\n' "$format_version"
        printf '# continuation session_id=%s previous_file=%s.1\n' "$session_id" "$output_name"
    } >"$log_file"
    chmod 0600 -- "$log_file"
}

append_record() {
    local record_kind=$1
    local event_types=$2
    local include_snapshot=$3
    local journal_since=${4:-"-20 seconds"}
    local key timestamp mono tmp_size

    record_sequence=$((record_sequence + 1))
    timestamp=$(wall_timestamp)
    mono=$(monotonic_ns)
    record_tmp=$(mktemp "$log_directory/.record.XXXXXX")
    chmod 0600 -- "$record_tmp"
    {
        printf 'BEGIN_RECORD sequence=%s kind=%s\n' "$record_sequence" "$record_kind"
        printf 'format_version: %s\n' "$format_version"
        printf 'session_id: %s\n' "$session_id"
        printf 'timestamp: %s\n' "$timestamp"
        printf 'monotonic_ns: %s\n' "$mono"
        printf 'sample_sequence: %s\n' "$sample_sequence"
        printf 'sample_started_monotonic_ns: %s\n' "$sample_started_monotonic_ns"
        printf 'expected_sample_monotonic_ns: %s\n' "$expected_sample_monotonic_ns"
        printf 'sampling_interval_ns: %s\n' "$sample_interval_ns"
        printf 'sampling_lateness_ns: %s\n' "$sampling_lateness_ns"
        printf 'event_types: %s\n' "${event_types:-none}"
        printf 'read_only: %s\n' "$([[ $reset_tmax == true ]] && printf false || printf true)"
        printf 'mock_mode: %s\n' "$mock_mode"
        printf 'last_event_sample: %s\n' "$last_event_sample"
        if [[ -n $collection_error ]]; then
            printf 'collection_error: %s\n' "$collection_error"
        fi
        printf 'values_begin:\n'
        while IFS= read -r key; do
            printf '  %s: %s\n' "$key" "${current[$key]}"
        done < <(printf '%s\n' "${!current[@]}" | sort)
        printf 'values_end\n'
        printf 'deltas_begin:\n'
        for key in "${numeric_keys[@]}"; do
            printf '  %s_since_start: %s\n' "$key" \
                "$(numeric_delta "${current[$key]:-unknown}" "${baseline[$key]:-unknown}")"
            printf '  %s_since_previous_sample: %s\n' "$key" \
                "$(numeric_delta "${current[$key]:-unknown}" "${previous[$key]:-unknown}")"
            printf '  %s_since_previous_record: %s\n' "$key" \
                "$(numeric_delta "${current[$key]:-unknown}" "${previous_record[$key]:-unknown}")"
        done
        printf 'deltas_end\n'
        if [[ $include_snapshot == true ]]; then
            write_rich_snapshot "$journal_since"
        fi
        printf 'END_RECORD sequence=%s\n\n' "$record_sequence"
    } >"$record_tmp"

    tmp_size=$(stat -c %s -- "$record_tmp")
    rotate_log_if_needed "$tmp_size"
    if [[ ! -f $log_file ]]; then
        printf '# mesa-7i95t-diagnostic-log format_version=%s\n' "$format_version" >"$log_file"
        chmod 0600 -- "$log_file"
    fi
    cat -- "$record_tmp" >>"$log_file"
    rm -f -- "$record_tmp"
    record_tmp=""
    for key in "${!current[@]}"; do
        previous_record[$key]=${current[$key]}
    done
}

copy_current_to() {
    local destination=$1
    local key
    for key in "${!current[@]}"; do
        if [[ $destination == baseline ]]; then
            baseline[$key]=${current[$key]}
        else
            previous[$key]=${current[$key]}
        fi
    done
}

detect_events() {
    local -a events=()
    local key value old

    if (( current[packet_total] > previous[packet_total] )); then
        events+=(packet_error_total_increased)
    fi
    if (( current[packet_level] != 0 )); then
        events+=(packet_error_level_nonzero)
    fi
    [[ ${current[packet_error]} == TRUE ]] && events+=(packet_error_true)
    [[ ${current[packet_exceeded]} == TRUE ]] && events+=(packet_error_exceeded_true)
    [[ ${current[io_error]} == TRUE ]] && events+=(io_error_true)

    for key in "${peak_keys[@]}"; do
        value=${current[$key]}
        old=${observed_peak[$key]}
        if (( value > old )); then
            events+=("${key}_new_peak")
            observed_peak[$key]=$value
        fi
    done
    for key in "${nic_event_keys[@]}"; do
        if [[ ${current[$key]} =~ ^[0-9]+$ && ${previous[$key]} =~ ^[0-9]+$ ]] &&
            (( current[$key] > previous[$key] )); then
            events+=("${key}_increased")
        fi
    done
    for key in "${change_keys[@]}"; do
        if [[ ${current[$key]} != "${previous[$key]}" ]]; then
            events+=("${key}_changed")
        fi
    done

    local joined=""
    detected_event_types=""
    if (( ${#events[@]} > 0 )); then
        printf -v joined '%s,' "${events[@]}"
        detected_event_types=${joined%,}
    fi
}

reset_timing_maxima() {
    local -a reset_names=(
        "${hal_prefix}.read-request.tmax"
        "${hal_prefix}.read.tmax"
        "${hal_prefix}.write.tmax"
        servo-thread.tmax
    )
    local name output status=0
    $mock_mode && return 0
    for name in "${reset_names[@]}"; do
        if ! output=$(halcmd setp "$name" 0 2>&1); then
            collection_error+=" reset_failed[$name]=$output"
            status=1
        fi
    done
    return "$status"
}

sleep_until_next_sample() {
    local now_ns delay_ns delay_seconds
    now_ns=$(monotonic_ns)
    delay_ns=$((next_sample_ns - now_ns))
    if (( delay_ns > 0 )); then
        delay_seconds=$(awk -v nanoseconds="$delay_ns" 'BEGIN {printf "%.9f\n", nanoseconds / 1000000000}')
        sleep "$delay_seconds" || true
    fi
}

if ! collect_core; then
    current[startup_failure]=true
    append_record error startup_collection_failed true "-5 minutes"
    printf 'Initial collection failed: %s\n' "$collection_error" >&2
    exit 1
fi
copy_current_to baseline
copy_current_to previous
for key in "${peak_keys[@]}"; do
    observed_peak[$key]=${current[$key]}
done
append_record startup baseline true "-5 minutes"

while [[ $stop_requested == false ]]; do
    sleep_until_next_sample
    [[ $stop_requested == false ]] || break

    actual_sample_ns=$(monotonic_ns)
    sample_started_monotonic_ns=$actual_sample_ns
    expected_sample_monotonic_ns=$next_sample_ns
    sampling_lateness_ns=$((actual_sample_ns - next_sample_ns))
    (( sampling_lateness_ns >= 0 )) || sampling_lateness_ns=0
    next_sample_ns=$((next_sample_ns + sample_interval_ns))
    sample_sequence=$((sample_sequence + 1))

    if ! collect_core; then
        append_record error sample_collection_failed true "-20 seconds"
    else
        if $rebaseline_peaks; then
            for key in "${peak_keys[@]}"; do
                observed_peak[$key]=${current[$key]}
            done
            rebaseline_peaks=false
        fi
        detect_events
        event_types=$detected_event_types
        include_snapshot=false
        record_kind=""
        if [[ -n $event_types ]]; then
            record_kind=event
            include_snapshot=true
            last_event_sample=$sample_sequence
        elif (( actual_sample_ns >= next_heartbeat_ns )); then
            record_kind=heartbeat
            include_snapshot=true
            event_types=periodic_heartbeat
        fi

        if [[ -n $record_kind ]]; then
            append_record "$record_kind" "$event_types" "$include_snapshot" "-20 seconds"
            if [[ $record_kind == event && $reset_tmax == true ]]; then
                collection_error=""
                if reset_timing_maxima; then
                    append_record mutation timing_maxima_reset false
                    rebaseline_peaks=true
                else
                    append_record error timing_maxima_reset_failed true "-20 seconds"
                fi
            fi
        fi
        copy_current_to previous
    fi

    if (( actual_sample_ns >= next_heartbeat_ns )); then
        while (( next_heartbeat_ns <= actual_sample_ns )); do
            next_heartbeat_ns=$((next_heartbeat_ns + heartbeat_interval_ns))
        done
    fi
    if (( max_samples > 0 && sample_sequence >= max_samples )); then
        stop_reason=max_samples
        break
    fi
done

collection_error=""
append_record shutdown "$stop_reason" true "-20 seconds"
printf 'Mesa diagnostic monitor stopped (%s); log %s\n' "$stop_reason" "$log_file"
exit "$stop_exit_code"
