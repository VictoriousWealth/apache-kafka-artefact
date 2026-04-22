#!/usr/bin/env bash
#
# auto-commit.sh – commit every newly-added results file individually
# ------------------------------------------------------------------
#  • Inspects `git status --porcelain`
#  • Builds a subject/body pair based on the file’s sub-category
#  • Adds & commits the file
#
#  Usage:  ./auto-commit.sh
# ------------------------------------------------------------------

set -euo pipefail

# ---------- helper: choose commit message by file pattern ----------
commit_msg () {
  local f=$1
  local subj body

  case "$f" in
    */topic-create.log)
      subj="feat(logging): add topic creation log for security overhead"
      body="This commit introduces a new log file that records \
the creation of a topic.\n\nThe log captures important details \
related to the benchmark for security overhead.\n\nThis addition \
will help in tracking and analyzing the performance of the topic."
      ;;
    */topic-delete.log)
      subj="feat(log): add topic delete log for MTLS broker"
      body="This commit introduces a new log file for topic deletion \
events.\n\nThe log will help in monitoring and debugging the MTLS \
broker's performance."
      ;;
    */producer-perf-*.log|*/producer-perf.log)
      # detect trial number if present
      if [[ $f =~ producer-perf-([0-9]+)\.log ]]; then
        trial=${BASH_REMATCH[1]}
        subj="feat(log): add producer performance log for trial ${trial}"
        body="This commit introduces a new log file capturing the \
performance metrics of the producer during trial ${trial}.\n\nThe \
log includes details such as records sent, throughput, and latency \
statistics.\n\nThese metrics are essential for analyzing the \
performance of the system under the specified conditions."
      else
        subj="feat(perf): add producer performance logging"
        body="This update introduces detailed logging for producer \
performance.\n\nThe logs include metrics such as records sent, \
throughput, and latency.\n\nThese changes will help in monitoring \
and optimizing producer performance."
      fi
      ;;
    */broker-[1-5].jsonl)
      broker=$(echo "$f" | sed -E 's|.*broker-([0-9]+)\.jsonl|\1|')
      subj="feat(broker-${broker}): add telemetry data for broker-${broker}"
      body="This update introduces new telemetry data for broker-${broker}.\n\n\
The added data includes CPU, memory, and network statistics over time.\n\n\
This information is crucial for monitoring and performance analysis."
      ;;
    */benchmark-client.jsonl|*/benchmark-client.log)
      subj="feat(benchmark-client): add telemetry data for performance analysis"
      body="This update introduces a significant amount of telemetry data.\n\n\
The new entries include CPU, memory, and network statistics over time.\n\n\
This data will help in analyzing the performance of the benchmark client."
      ;;
    */metadata.json)
      subj="feat(metadata): add metadata for security overhead trial"
      body="This commit introduces a new metadata.json file.\n\n\
It contains configuration details for the security overhead final factorial trial.\n\n\
This will help in tracking the parameters used during the benchmarking."
      ;;
    */result.json)
      subj="feat(result.json): add detailed security overhead results"
      body="This commit introduces a new JSON structure for the security overhead results.\n\n\
The added data includes run configurations, cluster settings, and performance metrics.\n\n\
These changes will help in better analysis and reporting of the security overhead during trials."
      ;;
    */completed.jsonl)
      subj="feat(results): add new run entries to completed.jsonl"
      body="Several new run entries have been added to the completed.jsonl file.\n\n\
These entries include additional trials for different configurations.\n\n\
This update enhances the data available for analysis."
      ;;
    *)
      subj="chore(results): add generated benchmark artifact"
      body="Adding generated benchmark artifact so that the full experimental \
dataset is preserved in version control."
      ;;
  esac

  printf '%s\n' "$subj"  # first line (subject)
  printf '\n%s\n' "$body"  # body (blank line first)
}

# ----------------------- main loop --------------------------------
git status --porcelain | grep '^?? ' | sed 's/^?? //' | while read -r file; do
  msg=$(commit_msg "$file")            # build commit message
  git add -- "$file"                   # stage the file
  git commit -m "$(echo "$msg" | head -1)" -m "$(echo "$msg" | tail -n +3)"
  printf "✔ committed %s\n" "$file"
done
