# Initial Experiment Matrix

## Purpose

This document defines the first-pass scenario set for the benchmarking artefact. It is intentionally narrow so the initial implementation stays aligned with the dissertation scope.

## Baseline Comparison Set

The first comparison should keep all non-security settings fixed and vary only:

- `security_mode = plaintext`
- `security_mode = tls`
- `security_mode = mtls`

## Initial Workloads

The first workload definitions should be simple and interpretable.

### Low

- smaller message size
- lower producer intensity
- intended to represent light traffic

### Medium

- moderate message size
- moderate producer intensity
- intended to represent steady operational load

### High

- larger message size or higher producer intensity
- intended to push the broker closer to saturation

## First Implementation Matrix

The minimum useful matrix is:

| Security Mode | Workload |
| --- | --- |
| plaintext | low |
| plaintext | medium |
| plaintext | high |
| tls | low |
| tls | medium |
| tls | high |
| mtls | low |
| mtls | medium |
| mtls | high |

## Second-Phase Sweeps

After the baseline matrix works correctly, secondary variables can be explored one at a time:

- `message_size`
- `producer_count`
- `partition_count`
- `batch_size`
- `acks`

These should be introduced only after the baseline matrix is stable.

## Reporting Guidance

The dissertation does not need to include every run the framework can perform. It should include:

- the baseline security comparison
- a justified subset of secondary sweeps
- enough repetition to support a credible interpretation
