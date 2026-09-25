#!/usr/bin/env bash
set -euo pipefail

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
log_directory="$script_directory/diagnostic-logs"
mode=summary
event_filter=""
since_timestamp=""
around_value=""
output_format=table
record_selector=""
record_sections="core,values,deltas"
max_lines=200
input_files=()

usage() {
    cat <<'EOF'
Usage: ./diagnostics-report.sh [OPTIONS] [LOG ...]

Read Mesa diagnostic logs without modifying them. With no LOG, the newest
primary *.log in diagnostic-logs/ is used.

Options:
  --summary                  Show aggregate counts and maxima (default)
  --timeline                 Show one compact row per complete record
  --events TEXT              Select records whose event_types contains TEXT
  --packet-errors            Select communication-error event records
  --investigation-bundle     Show summary plus packet events and neighbors
  --record SELECTOR          Extract SEQUENCE or SESSION_ID:SEQUENCE
  --sections LIST            Record sections (default: core,values,deltas)
  --since TIMESTAMP          Exclude records before the ISO-8601 timestamp
  --around VALUE             Show matching sequence/timestamp and neighbors
  --format table|tsv         Select aligned or tab-separated timeline output
  --max-lines COUNT          Bound record/bundle output (default: 200)
  -h, --help                 Show this help

Snapshot section names include irq_details, realtime_task, kernel_messages,
ethtool_statistics, cpu_policy, and host_state. Use --sections all only when a
complete selected record is genuinely required. Incomplete records are ignored.
EOF
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

while (( $# > 0 )); do
    case $1 in
        --summary) mode=summary; shift ;;
        --timeline) mode=timeline; shift ;;
        --events)
            (( $# >= 2 )) || die "--events requires text"
            event_filter=${2//-/_}; mode=timeline; shift 2
            ;;
        --packet-errors) event_filter=packet_error; mode=timeline; shift ;;
        --investigation-bundle) mode=bundle; shift ;;
        --record)
            (( $# >= 2 )) || die "--record requires a selector"
            record_selector=$2; mode=record; shift 2
            ;;
        --sections)
            (( $# >= 2 )) || die "--sections requires a comma-separated list"
            record_sections=$2; shift 2
            ;;
        --since)
            (( $# >= 2 )) || die "--since requires a timestamp"
            since_timestamp=$2; shift 2
            ;;
        --around)
            (( $# >= 2 )) || die "--around requires a sequence or timestamp"
            around_value=$2; mode=timeline; shift 2
            ;;
        --format)
            (( $# >= 2 )) || die "--format requires table or tsv"
            output_format=$2; shift 2
            ;;
        --max-lines)
            (( $# >= 2 )) || die "--max-lines requires a count"
            max_lines=$2; shift 2
            ;;
        -h|--help) usage; exit 0 ;;
        --) shift; input_files+=("$@"); break ;;
        -*) die "unknown option: $1" ;;
        *) input_files+=("$1"); shift ;;
    esac
done

[[ $output_format == table || $output_format == tsv ]] ||
    die "--format must be table or tsv"
[[ $max_lines =~ ^[1-9][0-9]*$ ]] || die "--max-lines must be positive"
[[ $record_sections =~ ^[A-Za-z0-9_,]+$ ]] ||
    die "--sections contains unsupported characters"
if [[ $mode != record && $record_sections != core,values,deltas ]]; then
    die "--sections requires --record"
fi
if [[ $mode == bundle ]] && (( max_lines < 20 )); then
    die "--max-lines must be at least 20 for an investigation bundle"
fi

record_session=""
record_sequence=""
if [[ $mode == record ]]; then
    if [[ $record_selector == *:* ]]; then
        record_session=${record_selector%:*}
        record_sequence=${record_selector##*:}
    else
        record_sequence=$record_selector
    fi
    [[ $record_sequence =~ ^[1-9][0-9]*$ ]] ||
        die "record selector must end in a positive sequence number"
    IFS=',' read -r -a requested_sections <<<"$record_sections"
    for requested_section in "${requested_sections[@]}"; do
        case $requested_section in
            all|core|values|deltas|mock_environment|hal_packet_pins|\
                hal_packet_parameters|hal_timing_parameters|hal_threads|\
                ip_link|ethtool_statistics|ethtool_driver|ethtool_link|\
                ethtool_eee|ethtool_offloads|network_protocol_statistics|\
                irq_details|realtime_task|benchmark_process|stress_ng_processes|\
                glxgears_processes|active_benchmark|kernel_messages|cpu_policy|\
                host_state)
                ;;
            *)
                die "unknown record section: $requested_section"
                ;;
        esac
    done
    if [[ $record_sections == *,all || $record_sections == all,* ]]; then
        die "section 'all' must be used alone"
    fi
fi

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

if [[ $mode == record ]]; then
    awk -v wanted_sequence="$record_sequence" -v wanted_session="$record_session" \
        -v sections="$record_sections" -v max_lines="$max_lines" '
function requested(name) {
    return sections == "all" || index("," sections ",", "," name ",") > 0
}
function emit(line) {
    output_lines++
    if (output_lines < max_lines) print line
    else truncated=1
}
function render_record(text,    count, lines, i, line, state, selected, label, snapshot_started) {
    count=split(text, lines, "\n")
    state="core"
    for (i=1; i<=count; i++) {
        line=lines[i]
        if (line == "") continue
        if (sections == "all") {emit(line); continue}
        if (line ~ /^BEGIN_RECORD / || line ~ /^END_RECORD / ||
            line ~ /^session_id: / || line ~ /^timestamp: / ||
            line ~ /^event_types: / || line ~ /^collection_error: /) {
            emit(line); continue
        }
        if (line == "values_begin:") {state="values"; if (requested("values")) emit(line); continue}
        if (line == "values_end") {if (requested("values")) emit(line); state="core"; continue}
        if (line == "deltas_begin:") {state="deltas"; if (requested("deltas")) emit(line); continue}
        if (line == "deltas_end") {if (requested("deltas")) emit(line); state="core"; continue}
        if (line == "snapshot_begin:") {state="snapshot"; selected=0; snapshot_started=0; continue}
        if (line == "snapshot_end") {
            if (snapshot_started) emit(line)
            state="core"; selected=0; continue
        }
        if (state == "snapshot" && line ~ /^  section: /) {
            label=line; sub(/^  section: /, "", label)
            selected=requested(label)
            if (selected && !snapshot_started) {emit("snapshot_begin:"); snapshot_started=1}
            if (selected) emit(line)
            continue
        }
        if (state == "snapshot") {if (selected) emit(line); continue}
        if (state == "values") {if (requested("values")) emit(line); continue}
        if (state == "deltas") {if (requested("deltas")) emit(line); continue}
        if (requested("core")) emit(line)
    }
    if (truncated) print "# output_truncated max_lines=" max_lines
}
/^BEGIN_RECORD / {
    open_record=1
    record_text=$0 ORS
    sequence=""; session=""
    for (field=1; field<=NF; field++) {
        if ($field ~ /^sequence=/) {sequence=$field; sub(/^sequence=/, "", sequence)}
    }
    next
}
open_record {
    record_text=record_text $0 ORS
    if ($0 ~ /^session_id: /) session=substr($0, 13)
}
/^END_RECORD / && open_record {
    end_sequence=$0; sub(/^END_RECORD sequence=/, "", end_sequence)
    if (end_sequence == sequence && sequence == wanted_sequence &&
        (wanted_session == "" || session == wanted_session)) {
        matches++
        if (matches == 1) selected_record=record_text
    }
    open_record=0
}
END {
    if (matches == 0) {
        print "No complete record matched --record " \
            (wanted_session == "" ? wanted_sequence : wanted_session ":" wanted_sequence) > "/dev/stderr"
        exit 4
    }
    if (matches > 1) {
        print "Record selector is ambiguous across the supplied logs; include SESSION_ID." > "/dev/stderr"
        exit 5
    }
    render_record(selected_record)
}
' "${input_files[@]}"
    exit
fi

awk -v report_mode="$mode" -v event_filter="$event_filter" \
    -v since_timestamp="$since_timestamp" -v around_value="$around_value" \
    -v output_format="$output_format" -v max_lines="$max_lines" '
function reset_record() {
    delete value
    delete delta
    sequence=kind=session=timestamp=events=lateness=collection_error=""
    in_values=in_deltas=0
}
function accepted() {
    if (since_timestamp != "" && timestamp < since_timestamp) return 0
    if (event_filter != "" && index(events, event_filter) == 0) return 0
    return 1
}
function row_text() {
    if (output_format == "tsv") {
        return source "\t" session "\t" sequence "\t" kind "\t" timestamp "\t" events "\t" \
            value["packet_total"] "\t" delta["packet_total_since_start"] "\t" \
            value["read_tmax_ns"] "\t" value["write_tmax_ns"] "\t" \
            value["servo_tmax_ns"] "\t" lateness "\t" \
            value["mesa_irq_count"] "\t" value["rt_cpu"] "\t" \
            value["rx_errors"] "\t" value["rx_dropped"] "\t" collection_error
    }
    return sprintf("%-18s %-29s %5s %-9s %-35s %-34s %7s %7s %11s %11s %11s %10s %8s %5s %6s %6s %s", \
        source, session, sequence, kind, timestamp, events, value["packet_total"], \
        delta["packet_total_since_start"], value["read_tmax_ns"], \
        value["write_tmax_ns"], value["servo_tmax_ns"], lateness, \
        value["mesa_irq_count"], value["rt_cpu"], value["rx_errors"], \
        value["rx_dropped"], collection_error)
}
function print_header() {
    if (header_printed) return
    if (output_format == "tsv")
        print "source\tsession_id\tseq\tkind\ttimestamp\tevents\tpacket_total\tpacket_delta_start\tread_tmax_ns\twrite_tmax_ns\tservo_tmax_ns\tlateness_ns\tmesa_irq_count\trt_cpu\trx_errors\trx_dropped\tcollection_error"
    else
        printf "%-18s %-29s %5s %-9s %-35s %-34s %7s %7s %11s %11s %11s %10s %8s %5s %6s %6s %s\n", \
            "SOURCE", "SESSION", "SEQ", "KIND", "TIMESTAMP", "EVENTS", "PACKETS", \
            "DELTA", "READ_TMAX", "WRITE_TMAX", "SERVO_TMAX", "LATE_NS", \
            "MESA_IRQ", "RTCPU", "RXERR", "RXDROP", "COLLECTION_ERROR"
    header_printed=1
}
function print_summary() {
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
}
function save_record(    n) {
    if (!accepted()) return
    total++
    kinds[kind]++
    if (first_timestamp == "") first_timestamp=timestamp
    last_timestamp=timestamp
    if (value["packet_total"] ~ /^[0-9]+$/) {
        if (first_packet == "") first_packet=value["packet_total"]
        last_packet=value["packet_total"]
    }
    packet_event=(index(events, "packet_error") > 0)
    if (packet_event) packet_events++
    if (value["read_tmax_ns"]+0 > max_read) max_read=value["read_tmax_ns"]+0
    if (value["write_tmax_ns"]+0 > max_write) max_write=value["write_tmax_ns"]+0
    if (value["servo_tmax_ns"]+0 > max_servo) max_servo=value["servo_tmax_ns"]+0
    if (lateness+0 > max_lateness) max_lateness=lateness+0
    if (report_mode == "timeline" || report_mode == "bundle") {
        n=++saved_count
        saved[n]=row_text()
        saved_sequence[n]=sequence
        saved_timestamp[n]=timestamp
        saved_packet_event[n]=packet_event
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
open_record && /^session_id: / {session=substr($0, 13); next}
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
    if (end_sequence == sequence) save_record()
    open_record=0
}
END {
    if (report_mode == "summary") {print_summary(); exit}
    if (report_mode == "bundle") {
        print_summary()
        print ""
        print "packet_event_context:"
        print_header()
        output_lines=19
        for (i=1; i<=saved_count; i++) {
            if (saved_packet_event[i]) {
                selected[i]=1
                if (i > 1) selected[i-1]=1
                if (i < saved_count) selected[i+1]=1
            }
        }
        for (i=1; i<=saved_count; i++) {
            if (!selected[i]) continue
            output_lines++
            if (output_lines < max_lines) print saved[i]
            else truncated=1
        }
        if (truncated) print "# output_truncated max_lines=" max_lines
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
