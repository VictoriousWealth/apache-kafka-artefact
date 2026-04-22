#!/usr/bin/env bash
#
# auto_commit.sh – keep committing files one-by-one until repo is clean
# -------------------------------------------------------------------
#  • Handles every porcelain status:
#       ??   = untracked
#       A    = already staged
#      " A"  = added in work-tree but not yet staged   ◀─ NEW
#       M    = modified
#      " M"  = modified in work-tree only
#       D    = deleted (staged or unstaged)
#  • Generates the same multi-line messages you used before.
# -------------------------------------------------------------------

set -euo pipefail

# ------------------------------------------------ helper -------------
commit_msg () {
  local f=$1 subj body trial broker

  case "$f" in
    */topic-create.log)
      subj="feat(logging): add topic creation log for security overhead"
      body="This commit introduces a new log file that records the creation \
of a topic.\n\nThe log captures important details related to the benchmark \
for security overhead and aids later analysis."
      ;;
    */topic-delete.log)
      subj="feat(log): add topic delete log for MTLS broker"
      body="This commit introduces a new log file for topic deletion events.\n\n\
The log will help in monitoring and debugging the MTLS broker's performance."
      ;;
    */producer-perf-*.log|*/producer-perf.log)
      if [[ $f =~ producer-perf-([0-9]+)\.log ]]; then
        trial=${BASH_REMATCH[1]}
        subj="feat(log): add producer performance log for trial ${trial}"
        body="Adds a producer performance log capturing metrics for trial \
${trial} (records sent, throughput, latency) so we can evaluate performance \
under the specified conditions."
      else
        subj="feat(perf): add producer performance logging"
        body="Introduces detailed logging for producer performance (records \
sent, throughput, latency) to support optimisation."
      fi
      ;;
    */broker-[1-5].jsonl)
      broker=$(echo "$f" | sed -E 's/.*broker-([0-9]+)\.jsonl/\1/')
      subj="feat(broker-${broker}): add telemetry data"
      body="Adds CPU, memory and network telemetry for broker-${broker}, \
enabling fine-grained monitoring and future tuning."
      ;;
    */benchmark-client.jsonl|*/benchmark-client.log)
      subj="feat(benchmark-client): add client telemetry"
      body="Adds benchmark-client telemetry (CPU/memory/network) for deeper \
performance insight."
      ;;
    */metadata.json)
      subj="feat(metadata): add metadata for security overhead trial"
      body="Adds metadata.json containing configuration parameters for the \
security-overhead factorial trials."
      ;;
    */result.json)
      subj="feat(result.json): add detailed trial results"
      body="Adds result.json with configuration, cluster settings and \
performance metrics for accurate post-processing."
      ;;
    */completed.jsonl)
      subj="feat(results): append runs to completed.jsonl"
      body="Adds new trial entries, expanding the dataset available for \
analysis."
      ;;
    */summary.csv|*/summary.json)
      subj="chore(summary): update aggregate summaries"
      body="Regenerates summary files to reflect the latest set of trials."
      ;;
    */started.jsonl)
      subj="chore(run-tracker): update started.jsonl"
      body="Synchronises the run tracker with the newest experiment batches."
      ;;
    *)
      subj="chore(results): add generated benchmark artifact"
      body="Adds generated benchmark artifact to preserve the full \
experimental dataset."
      ;;
  esac

  printf '%s\n\n%s\n' "$subj" "$body"
}

# ------------------------------------------------ main loop ----------
while true; do
  entry=$(git status --porcelain | head -n1) || true
  [[ -z $entry ]] && { echo "✅  repository clean"; break; }

  status=${entry:0:2}
  file=${entry:3}

  case "$status" in
    "??") git add -- "$file" ;;          # untracked
    "A " | "AM" ) : ;;                   # already in index → nothing to add
    " M" | "A?" ) git add -- "$file" ;;  # modified in WT / partly-added
    " A") git add -- "$file" ;;          # ◀─ NEW: WT shows Added, index empty
    " D" | "AD") git rm  -- "$file" ;;   # deleted
    *)   echo "⚠️  unhandled status '$status' for $file"; exit 1 ;;
  esac

  msg=$(commit_msg "$file")
  git commit -m "$(echo "$msg" | head -1)" -m "$(echo "$msg" | tail -n +3)"
  echo "✔ committed $file"
done