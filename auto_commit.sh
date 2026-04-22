#!/usr/bin/env bash
#
# auto_commit.sh – one-file-per-commit helper
# ------------------------------------------------------------
# • commits only recognised files (based on path templates)
# • skips + unstages everything else safely
# • handles full range of git status codes
# ------------------------------------------------------------

set -euo pipefail

# ---------- commit message generator -------------------------
commit_msg () {
  local f=$1 subj body trial broker

  case "$f" in
    auto_commit.sh)
      subj="chore(ci): update auto-commit helper"
      body="Improves handling of unknown files and git status edge cases." ;;

    */topic-create.log)
      subj="feat(logging): add topic creation log for security overhead"
      body="Introduces a log capturing topic creation events for benchmarking." ;;

    */topic-delete.log)
      subj="feat(log): add topic delete log for MTLS broker"
      body="Adds logging for topic deletions for debugging and monitoring." ;;

    */producer-perf-*.log|*/producer-perf.log)
      if [[ $f =~ producer-perf-([0-9]+)\.log ]]; then
        trial=${BASH_REMATCH[1]}
        subj="feat(log): add producer performance log for trial ${trial}"
        body="Adds throughput, latency, and record metrics for trial ${trial}."
      else
        subj="feat(perf): add producer performance logging"
        body="Introduces aggregated producer performance metrics."
      fi ;;

    */broker-[1-5].jsonl)
      broker=$(echo "$f" | sed -E 's/.*broker-([0-9]+)\.jsonl/\1/')
      subj="feat(broker-${broker}): add telemetry data"
      body="Adds CPU, memory, and network telemetry for broker ${broker}." ;;

    */benchmark-client.*)
      subj="feat(benchmark-client): add client telemetry"
      body="Adds telemetry metrics for benchmark client performance." ;;

    */metadata.json)
      subj="feat(metadata): add metadata for security overhead trial"
      body="Stores configuration parameters for benchmark trials." ;;

    */result.json)
      subj="feat(result.json): add detailed trial results"
      body="Stores full configuration and performance results for analysis." ;;

    */completed.jsonl)
      subj="feat(results): append runs to completed.jsonl"
      body="Adds completed trial entries to dataset." ;;

    */summary.csv|*/summary.json)
      subj="chore(summary): update aggregate summaries"
      body="Updates summary files with latest benchmark data." ;;

    */started.jsonl)
      subj="chore(run-tracker): update started.jsonl"
      body="Tracks newly started benchmark runs." ;;

    *) return 1 ;;
  esac

  printf '%s\n\n%s\n' "$subj" "$body"
}

# ---------- main loop ----------------------------------------
while true; do
  entry=$(git status --porcelain | head -n1) || true
  [[ -z $entry ]] && { echo "✅ repository clean"; break; }

  status=${entry:0:2}
  file=${entry:3}

  # ---------- skip unknown files ------------------------------
  if ! msg=$(commit_msg "$file"); then
    echo "🔸 skipping unrecognised file: $file"
    git restore --staged --quiet -- "$file" 2>/dev/null || true
    continue
  fi

  # ---------- stage/remove based on status --------------------
  case "$status" in
    "??") git add -- "$file" ;;          # untracked
    " A"|" M") git add -- "$file" ;;     # WT changes not staged
    "MM") git add -- "$file" ;;          # both index + WT modified
    "A " |"AM") : ;;                     # already staged
    "M ") : ;;                           # index-only change
    " D"|"AD") git rm -- "$file" ;;      # deleted
    *) echo "⚠️ unhandled status '$status' for $file"; exit 1 ;;
  esac

  # ---------- commit ------------------------------------------
  git commit -m "$(echo "$msg" | head -1)" \
              -m "$(echo "$msg" | tail -n +3)"

  echo "✔ committed $file"
done