# Deployment Hardening

## Current Protections

The plaintext deployment path now includes:

- atomic writes for generated local state and configuration files
- safe reruns for Kafka installation and cluster ID generation
- a resumable top-level deployment wrapper with checkpoints
- retries for transient SSH, SCP, and remote command failures
- post-start `systemd` health checks for each Kafka broker
- per-run host telemetry capture with raw JSONL files retained for auditability
- benchmark result parsing that preserves both application metrics and host telemetry summaries

## Control-C and Partial Execution

If the local orchestration is interrupted:

- temporary local files are cleaned up
- completed top-level steps remain recorded in the checkpoint file
- rerunning the top-level deployment wrapper resumes from the remaining steps

## Current Limits

The deployment flow is still a pragmatic shell-based system, not a full workflow engine.

Known limits:

- no cross-machine distributed transaction semantics
- no durable remote lock coordination across orchestration clients
- no automatic rollback on partial cluster success
- no quorum-level Kafka validation beyond per-node service checks
- telemetry is sampled from host-level `/proc` counters, so it is suitable for utilisation analysis but not a substitute for kernel-level profiling

## Next Hardening Options

If stronger reliability is needed later, the next upgrades should be:

1. explicit remote lock ownership and stale-lock expiry handling
2. topic-level or metadata-level Kafka readiness checks
3. structured per-step logs and failure summaries
4. explicit configuration drift checks before restart
5. telemetry completeness gates before accepting final campaign runs
