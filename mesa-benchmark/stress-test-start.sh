#!/usr/bin/env bash
set -euo pipefail

# Keep CPUs 2/8 (Mesa physical core) and 5/11 (LinuxCNC physical core) free.
stress_cpuset="${STRESS_CPUSET:-0-1,3-4,6-7,9-10}"
cpu_workers="${STRESS_CPU_WORKERS:-8}"
vm_workers="${STRESS_VM_WORKERS:-2}"
vm_bytes="${STRESS_VM_BYTES:-2G}"
duration="${STRESS_DURATION:-24h}"

for command_name in taskset stress-ng; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$command_name" >&2
        exit 1
    fi
done

printf 'Stress CPUs: %s (CPU workers: %s)\n' "$stress_cpuset" "$cpu_workers"
printf 'VM workers: %s, VM bytes: %s, duration: %s\n' \
    "$vm_workers" "$vm_bytes" "$duration"

exec taskset --cpu-list "$stress_cpuset" \
    stress-ng \
        --cpu "$cpu_workers" \
        --vm "$vm_workers" \
        --vm-bytes "$vm_bytes" \
        --timeout "$duration" \
        --metrics-brief

