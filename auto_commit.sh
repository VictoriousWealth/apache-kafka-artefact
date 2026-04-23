#!/usr/bin/env bash
#
# auto_commit.sh – one-file-per-commit helper
# ------------------------------------------------------------
# • commits only recognised files
# • skips unknown files
# • expands untracked directories into files inside them
# ------------------------------------------------------------

set -euo pipefail

commit_msg () {
  local f=$1 subj body trial broker

  case "$f" in
    auto_commit.sh)
      return 1 ;;

    */topic-create.log)
      subj="feat(logging): add topic creation log for security overhead"
      body="This commit introduces a new log file that records the creation of a topic.

The log captures important details related to the benchmark for security overhead.

This addition will help in tracking and analyzing the performance of the topic." ;;

    */topic-delete.log)
      subj="feat(log): add topic delete log for TLS broker"
      body="This commit introduces a new log file for topic deletion events.

The log will help in monitoring and debugging the TLS broker's performance." ;;

    */producer-perf-*.log)
      if [[ $f =~ producer-perf-([0-9]+)\.log ]]; then
        trial=${BASH_REMATCH[1]}
        subj="feat(log): add producer performance log for trial ${trial}"
        body="This commit introduces a new log file capturing the performance metrics of the producer during trial ${trial}.

The log includes details such as records sent, throughput, and latency statistics.

These metrics are essential for analyzing the performance of the system under the specified conditions."
      else
        return 1
      fi ;;

    */producer-perf.log)
      subj="feat(perf): add producer performance logging"
      body="This update introduces detailed logging for producer performance.

The logs include metrics such as records sent, throughput, and latency.

These changes will help in monitoring and optimizing producer performance." ;;

    */broker-[1-5].jsonl)
      broker=$(echo "$f" | sed -E 's/.*broker-([0-9]+)\.jsonl/\1/')
      case "$broker" in
        1)
          subj="feat(broker): add telemetry data for broker-1"
          body="This update introduces a significant amount of telemetry data for broker-1.

The added data includes CPU, memory, and network usage metrics over time.

These metrics are crucial for monitoring and performance analysis."
          ;;
        2)
          subj="feat(broker-2): add telemetry data for broker-2"
          body="This update introduces a significant amount of telemetry data for broker-2.

The added data includes CPU, memory, and network usage metrics over time.

This information is crucial for monitoring and performance analysis."
          ;;
        3)
          subj="feat(broker-3): add telemetry data for broker performance"
          body="This update introduces new telemetry data for broker-3.

The added lines include metrics such as CPU usage, memory usage, and network statistics.

These metrics are crucial for monitoring and optimizing broker performance."
          ;;
        4)
          subj="feat(telemetry): add broker-4 telemetry data"
          body="This update introduces new telemetry data for broker-4.

The data includes CPU, memory, and network statistics over time.

This information is crucial for monitoring and performance analysis."
          ;;
        5)
          subj="feat(broker-5): add telemetry data for broker 5"
          body="This commit introduces new telemetry data entries for broker 5.

The added data includes CPU, memory, and network statistics over time.

This information is crucial for monitoring and performance analysis."
          ;;
      esac ;;

    */benchmark-client.jsonl)
      subj="feat(benchmark-client): add telemetry data for performance analysis"
      body="This update introduces a significant amount of telemetry data.

The new entries include CPU, memory, and network statistics over time.

This data will help in analyzing the performance of the benchmark client." ;;

    */benchmark-client.log)
      subj="feat(benchmark-client): add new log file"
      body="This commit introduces a new log file for the benchmark client.

The log file will help in tracking performance metrics and debugging." ;;

    */metadata.json)
      subj="feat(metadata): add metadata for security overhead trial"
      body="This commit introduces a new metadata.json file.

It contains configuration details for the security overhead final factorial trial.

This will help in tracking the parameters used during the benchmarking." ;;

    */result.json)
      subj="feat(result.json): add detailed security overhead results"
      body="This commit introduces a new JSON structure for the security overhead results.

The added data includes run configurations, cluster settings, and performance metrics.

These changes will help in better analysis and reporting of the security overhead during trials." ;;

    */completed.jsonl)
      subj="feat(results): append runs to completed.jsonl"
      body="Adds new trial entries, expanding the dataset available for analysis." ;;

    */started.jsonl)
      subj="chore(run-tracker): update started.jsonl"
      body="Synchronises the run tracker with the newest experiment batches." ;;

    */summary.csv|*/summary.json)
      subj="chore(summary): update aggregate summaries"
      body="Regenerates summary files to reflect the latest set of trials." ;;

    *) return 1 ;;
  esac

  printf '%s\n\n%s\n' "$subj" "$body"
}

expand_entry () {
  local status="$1"
  local path="$2"

  if [[ "$status" == "??" && -d "$path" ]]; then
    find "$path" -type f | sort
  else
    printf '%s\n' "$path"
  fi
}

handle_file () {
  local status="$1"
  local file="$2"
  local msg

  if ! msg=$(commit_msg "$file"); then
    echo "🔸 skipping unrecognised file: $file"
    return 1
  fi

  case "$status" in
    "??") git add -- "$file" ;;
    " A") git add -- "$file" ;;
    " M") git add -- "$file" ;;
    "MM") git add -- "$file" ;;
    "A "|"AM") : ;;
    "M ") : ;;
    " D"|"AD") git rm -- "$file" ;;
    *)
      echo "⚠️ unhandled status '$status' for $file"
      return 1
      ;;
  esac

  git commit -m "$(echo "$msg" | head -1)" \
              -m "$(echo "$msg" | tail -n +3)"

  echo "✔ committed $file"
  return 0
}

while true; do
  mapfile -t entries < <(git status --porcelain)

  if [[ ${#entries[@]} -eq 0 ]]; then
    echo "✅ repository clean"
    break
  fi

  committed_any=false

  for entry in "${entries[@]}"; do
    status=${entry:0:2}
    path=${entry:3}

    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      if handle_file "$status" "$file"; then
        committed_any=true
        break 2
      fi
    done < <(expand_entry "$status" "$path")
  done

  if [[ "$committed_any" == false ]]; then
    echo "✅ no recognised files left to auto-commit"
    break
  fi
done