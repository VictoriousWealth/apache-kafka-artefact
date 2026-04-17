#!/usr/bin/env bash

set -Eeuo pipefail

ROLE="host"
HOST_ID="$(hostname)"
INTERVAL_SECONDS="1"
OUTPUT_FILE=""

usage() {
  cat <<'EOF'
Usage: collect_host_telemetry.sh --output <file> [--role <role>] [--host-id <id>] [--interval <seconds>]

Writes newline-delimited JSON samples containing CPU, memory, network, and disk counters.
The process runs until it receives SIGTERM or SIGINT.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --role)
      ROLE="$2"
      shift 2
      ;;
    --host-id)
      HOST_ID="$2"
      shift 2
      ;;
    --interval)
      INTERVAL_SECONDS="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${OUTPUT_FILE}" ]]; then
  echo "Missing --output." >&2
  usage >&2
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT_FILE}")"
touch "${OUTPUT_FILE}"
chmod a+r "${OUTPUT_FILE}" || true

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/ }"
  printf '%s' "${value}"
}

read_cpu_totals() {
  awk '/^cpu / {
    idle=$5+$6
    total=0
    for (i=2; i<=NF; i++) total+=$i
    print total, idle
  }' /proc/stat
}

read_memory() {
  awk '
    /^MemTotal:/ {total=$2}
    /^MemAvailable:/ {available=$2}
    END {
      used=total-available
      pct=(total > 0) ? (used * 100 / total) : 0
      printf "%d %d %.2f\n", total, used, pct
    }
  ' /proc/meminfo
}

read_network() {
  awk -F '[: ]+' '
    NR > 2 && $2 != "lo" {
      rx += $3
      tx += $11
    }
    END {
      printf "%d %d\n", rx, tx
    }
  ' /proc/net/dev
}

read_disk() {
  awk '
    $3 ~ /^(sd|vd|xvd)[a-z]+$/ || $3 ~ /^nvme[0-9]+n[0-9]+$/ || $3 ~ /^mmcblk[0-9]+$/ {
      read_sectors += $6
      write_sectors += $10
    }
    END {
      printf "%d %d\n", read_sectors, write_sectors
    }
  ' /proc/diskstats
}

RUNNING=true
stop() {
  RUNNING=false
}
trap stop INT TERM

read -r prev_total prev_idle < <(read_cpu_totals)

while [[ "${RUNNING}" == "true" ]]; do
  sleep "${INTERVAL_SECONDS}" || true

  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  epoch_ms="$(date -u +%s%3N 2>/dev/null || printf '%s000' "$(date -u +%s)")"
  read -r total idle < <(read_cpu_totals)
  read -r mem_total_kb mem_used_kb mem_used_percent < <(read_memory)
  read -r net_rx_bytes net_tx_bytes < <(read_network)
  read -r disk_read_sectors disk_write_sectors < <(read_disk)

  total_delta=$((total - prev_total))
  idle_delta=$((idle - prev_idle))
  if (( total_delta > 0 )); then
    cpu_percent="$(awk -v total_delta="${total_delta}" -v idle_delta="${idle_delta}" 'BEGIN { printf "%.2f", ((total_delta - idle_delta) * 100 / total_delta) }')"
  else
    cpu_percent="0.00"
  fi

  printf '{"timestamp":"%s","epoch_ms":%s,"role":"%s","host_id":"%s","cpu_percent":%s,"memory_total_kb":%s,"memory_used_kb":%s,"memory_used_percent":%s,"network_rx_bytes":%s,"network_tx_bytes":%s,"disk_read_sectors":%s,"disk_write_sectors":%s}\n' \
    "${timestamp}" \
    "${epoch_ms}" \
    "$(json_escape "${ROLE}")" \
    "$(json_escape "${HOST_ID}")" \
    "${cpu_percent}" \
    "${mem_total_kb}" \
    "${mem_used_kb}" \
    "${mem_used_percent}" \
    "${net_rx_bytes}" \
    "${net_tx_bytes}" \
    "${disk_read_sectors}" \
    "${disk_write_sectors}" \
    >> "${OUTPUT_FILE}"

  prev_total="${total}"
  prev_idle="${idle}"
done

chmod a+r "${OUTPUT_FILE}" || true
