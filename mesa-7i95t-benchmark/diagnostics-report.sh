#!/usr/bin/env bash
set -euo pipefail

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
log_directory="$script_directory/diagnostic-logs"
mode=summary
event_filter=""
since_timestamp=""
around_value=""
output_format=table
input_files=()

usage() {
    cat <<'EOF'
Usage: ./diagnostics-report.sh [OPTIONS] [LOG ...]

Read Mesa diagnostic logs without modifying them. With no LOG, the newest
primary *.log in diagnostic-logs/ is used.

Options:
  --summary             Show aggregate counts and maxima (default)
  --timeline            Show one compact row per complete record
  --events TEXT         Show records whose event_types contains TEXT
  --since TIMESTAMP     Exclude records before the ISO-8601 timestamp
  --around VALUE        Show the matching sequence/timestamp and neighbors
  --format table|tsv    Select aligned or tab-separated output
  -h, --help            Show this help

Only records with matching BEGIN_RECORD and END_RECORD lines are reported.
Hyphens in --events are treated as underscores.
EOF
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

while (( $# > 0 )); do
    case $1 in
        --summary)
            mode=summary
            shift
            ;;
        --timeline)
            mode=timeline
            shift
            ;;
        --events)
            (( $# >= 2 )) || die "--events requires text"
            event_filter=${2//-/_}
            mode=timeline
            shift 2
            ;;
        --since)
            (( $# >= 2 )) || die "--since requires a timestamp"
            since_timestamp=$2
            shift 2
            ;;
        --around)
            (( $# >= 2 )) || die "--around requires a sequence or timestamp"
            around_value=$2
            mode=timeline
            shift 2
            ;;
        --format)
            (( $# >= 2 )) || die "--format requires table or tsv"
            output_format=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            input_files+=("$@")
            break
            ;;
        -*)
            die "unknown option: $1"
            ;;
        *)
            input_files+=("$1")
            shift
            ;;
    esac
done

[[ $output_format == table || $output_format == tsv ]] ||
    die "--format must be table or tsv"

if (( ${#input_files[@]} == 0 )); then
    shopt -s nullglob
    candidates=("$log_directory"/*.log)
    shopt -u nullglob
    newest=""
    for candidate in "${candidates[@]}"; do
        [[ ${candidate##*/} == monitor-console.log ]] && continue
        if [[ -z $newest || $candidate -nt $newest ]]; then
            newest=$candidate
        fi
    done
    [[ -n $newest ]] || die "no diagnostic *.log files found in $log_directory"
    input_files=("$newest")
fi

for input_file in "${input_files[@]}"; do
    [[ -r $input_file ]] || die "log is not readable: $input_file"
done

awk -v report_mode="$mode" -v event_filter="$event_filter" \
    -v since_timestamp="$since_timestamp" -v around_value="$around_value" \
    -v output_format="$output_format" '
function reset_record(    key) {
    delete value
    delete delta
    sequence=kind=timestamp=events=lateness=collection_error=""
    in_values=in_deltas=0
}
function accepted() {
    if (since_timestamp != "" && timestamp < since_timestamp) return 0
    if (event_filter != "" && index(events, event_filter) == 0) return 0
    return 1
}
function row_text(    separator) {
    separator=(output_format == "tsv" ? "\t" : " ")
    if (output_format == "tsv") {
        return source "\t" sequence "\t" kind "\t" timestamp "\t" events "\t" \
            value["packet_total"] "\t" delta["packet_total_since_start"] "\t" \
            value["read_tmax_ns"] "\t" value["write_tmax_ns"] "\t" \
            value["servo_tmax_ns"] "\t" lateness "\t" \
            value["mesa_irq_count"] "\t" value["rt_cpu"] "\t" \
            value["rx_errors"] "\t" value["rx_dropped"] "\t" collection_error
    }
    return sprintf("%-18s %5s %-9s %-35s %-34s %7s %7s %11s %11s %11s %10s %8s %5s %6s %6s %s", \
        source, sequence, kind, timestamp, events, value["packet_total"], \
        delta["packet_total_since_start"], value["read_tmax_ns"], \
        value["write_tmax_ns"], value["servo_tmax_ns"], lateness, \
        value["mesa_irq_count"], value["rt_cpu"], value["rx_errors"], \
        value["rx_dropped"], collection_error)
}
function print_header() {
    if (header_printed) return
    if (output_format == "tsv")
        print "source\tseq\tkind\ttimestamp\tevents\tpacket_total\tpacket_delta_start\tread_tmax_ns\twrite_tmax_ns\tservo_tmax_ns\tlateness_ns\tmesa_irq_count\trt_cpu\trx_errors\trx_dropped\tcollection_error"
    else
        printf "%-18s %5s %-9s %-35s %-34s %7s %7s %11s %11s %11s %10s %8s %5s %6s %6s %s\n", \
            "SOURCE", "SEQ", "KIND", "TIMESTAMP", "EVENTS", "PACKETS", \
            "DELTA", "READ_TMAX", "WRITE_TMAX", "SERVO_TMAX", "LATE_NS", \
            "MESA_IRQ", "RTCPU", "RXERR", "RXDROP", "COLLECTION_ERROR"
    header_printed=1
}
function save_or_print(    n) {
    if (!accepted()) return
    total++
    kinds[kind]++
    if (first_timestamp == "") first_timestamp=timestamp
    last_timestamp=timestamp
    if (value["packet_total"] ~ /^[0-9]+$/) {
        if (first_packet == "") first_packet=value["packet_total"]
        last_packet=value["packet_total"]
    }
    if (index(events, "packet_error") > 0) packet_events++
    if (value["read_tmax_ns"]+0 > max_read) max_read=value["read_tmax_ns"]+0
    if (value["write_tmax_ns"]+0 > max_write) max_write=value["write_tmax_ns"]+0
    if (value["servo_tmax_ns"]+0 > max_servo) max_servo=value["servo_tmax_ns"]+0
    if (lateness+0 > max_lateness) max_lateness=lateness+0
    if (report_mode == "timeline") {
        n=++saved_count
        saved[n]=row_text()
        saved_sequence[n]=sequence
        saved_timestamp[n]=timestamp
    }
}
/^BEGIN_RECORD / {
    reset_record()
    open_record=1
    source=FILENAME
    sub(/^.*\//, "", source)
    for (field=1; field<=NF; field++) {
        if ($field ~ /^sequence=/) {sequence=$field; sub(/^sequence=/, "", sequence)}
        if ($field ~ /^kind=/) {kind=$field; sub(/^kind=/, "", kind)}
    }
    next
}
open_record && /^timestamp: / {timestamp=substr($0, 12); next}
open_record && /^event_types: / {events=substr($0, 14); next}
open_record && /^sampling_lateness_ns: / {lateness=substr($0, 23); next}
open_record && /^collection_error: / {collection_error=substr($0, 19); next}
open_record && /^values_begin:/ {in_values=1; next}
open_record && /^values_end/ {in_values=0; next}
open_record && /^deltas_begin:/ {in_deltas=1; next}
open_record && /^deltas_end/ {in_deltas=0; next}
open_record && in_values && /^  [^:]+: / {
    line=substr($0, 3); split_at=index(line, ": ")
    key=substr(line, 1, split_at-1); value[key]=substr(line, split_at+2); next
}
open_record && in_deltas && /^  [^:]+: / {
    line=substr($0, 3); split_at=index(line, ": ")
    key=substr(line, 1, split_at-1); delta[key]=substr(line, split_at+2); next
}
/^END_RECORD / && open_record {
    end_sequence=$0; sub(/^END_RECORD sequence=/, "", end_sequence)
    if (end_sequence == sequence) save_or_print()
    open_record=0
}
END {
    if (report_mode == "summary") {
        print "records: " total
        print "first_timestamp: " (first_timestamp == "" ? "none" : first_timestamp)
        print "last_timestamp: " (last_timestamp == "" ? "none" : last_timestamp)
        print "startup_records: " (kinds["startup"]+0)
        print "event_records: " (kinds["event"]+0)
        print "packet_error_event_records: " (packet_events+0)
        print "heartbeat_records: " (kinds["heartbeat"]+0)
        print "error_records: " (kinds["error"]+0)
        print "mutation_records: " (kinds["mutation"]+0)
        print "shutdown_records: " (kinds["shutdown"]+0)
        print "packet_total_first: " (first_packet == "" ? "unknown" : first_packet)
        print "packet_total_last: " (last_packet == "" ? "unknown" : last_packet)
        print "max_read_tmax_ns: " (max_read+0)
        print "max_write_tmax_ns: " (max_write+0)
        print "max_servo_tmax_ns: " (max_servo+0)
        print "max_sampling_lateness_ns: " (max_lateness+0)
        exit
    }
    print_header()
    if (around_value == "") {
        for (i=1; i<=saved_count; i++) print saved[i]
        exit
    }
    match_index=0
    for (i=1; i<=saved_count; i++) {
        if (saved_sequence[i] == around_value || index(saved_timestamp[i], around_value) > 0) {
            match_index=i
            break
        }
    }
    if (!match_index) {
        print "No complete record matched --around " around_value > "/dev/stderr"
        exit 4
    }
    start=(match_index > 1 ? match_index-1 : match_index)
    finish=(match_index < saved_count ? match_index+1 : match_index)
    for (i=start; i<=finish; i++) print saved[i]
}
' "${input_files[@]}"
