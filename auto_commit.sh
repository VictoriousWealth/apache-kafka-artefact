#!/usr/bin/env bash
#
# auto_commit.sh – one-file-per-commit helper
# ------------------------------------------------------------
# • commits only recognised files
# • skips unknown files
# • expands untracked directories into files inside them
# ------------------------------------------------------------

set -euo pipefail

extract_result_set () {
  local f=$1

  if [[ $f =~ ^results/[^/]+/([^/]+)/ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf 'unknown-result-set\n'
  fi
}

extract_run_id () {
  local f=$1

  if [[ $f =~ ^results/[^/]+/[^/]+/([^/]+)/ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf 'unknown-run\n'
  fi
}

extract_host_label () {
  local f=$1

  if [[ $f =~ /(broker-[0-9]+|benchmark-client)\.(jsonl|log)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf 'unknown-host\n'
  fi
}

commit_msg () {
  local f=$1 subj body trial broker result_set run_id host_label
  result_set=$(extract_result_set "$f")
  run_id=$(extract_run_id "$f")
  host_label=$(extract_host_label "$f")

  case "$f" in
    auto_commit.sh)
      return 1 ;;

    dissertation.pdf)
      subj="docs(dissertation): update compiled dissertation PDF"
      body="This commit updates the compiled dissertation PDF.

The PDF reflects the latest dissertation edits, regenerated figures, refreshed tables, and updated supporting material.

Keeping the compiled output in version control makes review and submission-state tracking easier." ;;

    */topic-predelete.log)
      subj="feat(cleanup): add topic pre-delete log for ${run_id}"
      body="This commit adds the topic pre-delete log for run \`${run_id}\` in result set \`${result_set}\`.

The log captures the cleanup step before topic recreation and helps diagnose stale-topic issues during repeated benchmark execution.

This improves traceability for reruns, checkpoint recovery, and consumer/prodcer pipeline cleanup validation." ;;

    */topic-create.log)
      subj="feat(topic): add creation log for ${run_id}"
      body="This commit adds the topic creation log for run \`${run_id}\` in result set \`${result_set}\`.

The log records the topic setup step that precedes benchmark execution.

This supports auditability of benchmark setup and topic lifecycle behaviour." ;;

    */topic-delete.log)
      subj="feat(topic): add delete log for ${run_id}"
      body="This commit adds the topic deletion log for run \`${run_id}\` in result set \`${result_set}\`.

The log records the cleanup step after benchmark execution and helps verify topic lifecycle correctness." ;;

    */producer-perf-*.log)
      if [[ $f =~ producer-perf-([0-9]+)\.log ]]; then
        trial=${BASH_REMATCH[1]}
        subj="feat(producer-log): add shard ${trial} log for ${run_id}"
        body="This commit adds producer shard log \`${trial}\` for run \`${run_id}\` in result set \`${result_set}\`.

The log captures the per-producer benchmark output for this concurrent producer run.

This helps inspect producer spread, throughput balance, and per-process latency behaviour."
      else
        return 1
      fi ;;

    */producer-perf.log)
      subj="feat(producer): add aggregate perf log for ${run_id}"
      body="This commit adds the aggregate producer performance log for run \`${run_id}\` in result set \`${result_set}\`.

The log includes records sent, throughput, and latency statistics for the full producer benchmark.

This is one of the primary raw artefacts used for parsing and final analysis." ;;

    */producer-seed.log)
      subj="feat(seed): add producer seed log for ${run_id}"
      body="This commit adds the producer seed log for run \`${run_id}\` in result set \`${result_set}\`.

The log records the producer-side topic seeding step that populates records before consumer measurement begins.

This is needed to audit the read-path validation pipeline end to end." ;;

    */consumer-perf.log)
      subj="feat(consumer): add perf log for ${run_id}"
      body="This commit adds the consumer performance log for run \`${run_id}\` in result set \`${result_set}\`.

The log captures throughput and timing data produced during the consumer benchmark stage.

These metrics are needed to compare secure transport overhead on the Kafka read path." ;;

    */broker-[1-5].jsonl)
      broker=$(echo "$f" | sed -E 's/.*broker-([0-9]+)\.jsonl/\1/')
      subj="feat(telemetry): add broker-${broker} metrics for ${run_id}"
      body="This commit adds broker-\`${broker}\` host telemetry for run \`${run_id}\` in result set \`${result_set}\`.

The telemetry includes time-series CPU, memory, network, and disk metrics collected during benchmark execution.

This supports resource-level attribution of performance overhead on the broker side." ;;

    */benchmark-client.jsonl)
      subj="feat(telemetry): add benchmark-client metrics for ${run_id}"
      body="This commit adds benchmark-client host telemetry for run \`${run_id}\` in result set \`${result_set}\`.

The telemetry includes time-series CPU, memory, network, and disk metrics collected during the benchmark.

This supports analysis of client-side overhead under plaintext, TLS, or mTLS." ;;

    */benchmark-client.log)
      subj="feat(telemetry): add benchmark-client collector log for ${run_id}"
      body="This commit adds the benchmark-client telemetry collector log for run \`${run_id}\` in result set \`${result_set}\`.

The log helps diagnose telemetry collection behaviour and supports debugging when host metrics look incomplete." ;;

    */metadata.json)
      subj="feat(metadata): add run metadata for ${run_id}"
      body="This commit adds the metadata file for run \`${run_id}\` in result set \`${result_set}\`.

It captures workload, security mode, broker configuration, and execution settings for this benchmark row.

This is the main provenance record used to trace results back to the executed configuration." ;;

    */result.json)
      subj="feat(result): add parsed metrics for ${run_id}"
      body="This commit adds the parsed \`result.json\` for run \`${run_id}\` in result set \`${result_set}\`.

The file includes workload metadata, cluster settings, parsed benchmark metrics, and aggregated host telemetry.

This is one of the primary structured artefacts used for analysis and dissertation reporting." ;;

    */export/table.csv)
      subj="chore(export): add CSV table export for ${result_set}"
      body="This commit adds a generated CSV table export for result set \`${result_set}\`.

The export is intended for analysis, reporting, and dissertation table preparation." ;;

    */export/table.tex)
      subj="chore(export): add LaTeX table export for ${result_set}"
      body="This commit adds a generated LaTeX table export for result set \`${result_set}\`.

The export supports direct inclusion of benchmark summaries in the dissertation." ;;

    */export/*.svg)
      subj="chore(export): add SVG plot export for ${result_set}"
      body="This commit adds a generated SVG plot export derived from result set \`${result_set}\`.

The export supports dissertation figures and reproducible visual analysis." ;;

    */completed.jsonl)
      subj="chore(results): update completed ledger for ${result_set}"
      body="This commit updates \`completed.jsonl\` for result set \`${result_set}\`.

The ledger records which benchmark rows completed successfully and were copied back with parsed outputs.

This file is part of the authoritative completion record for the campaign." ;;

    */started.jsonl)
      subj="chore(results): update started ledger for ${result_set}"
      body="This commit updates \`started.jsonl\` for result set \`${result_set}\`.

The ledger records which benchmark rows have begun execution under the orchestration pipeline.

This supports checkpointed execution and recovery after interruption." ;;

    */failures.jsonl)
      subj="chore(results): update failure ledger for ${result_set}"
      body="This commit updates \`failures.jsonl\` for result set \`${result_set}\`.

The ledger records failed or timed-out benchmark attempts as execution-history evidence.

Rows listed here may later be rerun successfully and should be interpreted alongside the completion ledger." ;;

    */summary.csv|*/summary.json)
      subj="chore(summary): refresh aggregate summary for ${result_set}"
      body="This commit refreshes an aggregate summary file for result set \`${result_set}\`.

The summary reflects the latest completed benchmark rows and supports downstream analysis and comparison export." ;;

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
