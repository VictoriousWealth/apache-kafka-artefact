# Initial Sweep Set

## Purpose

This document defines the first-pass sweep set for the benchmarking artefact. It is intentionally narrow so the initial implementation stays aligned with the dissertation scope.

## Baseline Configuration

The first baseline should keep all non-security settings fixed while the chosen sweep variable varies.

- baseline name: `plaintext-default`

## Initial Sweep Definitions

The first sweep definitions should be simple and interpretable.

### Security Mode Sweep

- variable: `security_mode`
- values: `plaintext`, `tls`, `mtls`

### Message Size Sweep

- variable: `message_size_bytes`
- values: `1024`, `10240`, `102400`

### Throughput Sweep

- variable: `target_messages_per_second`
- values: `1000`, `10000`, `50000`

## First Implementation Set

The minimum useful implementation set is:

- one baseline file
- one plaintext-executable sweep such as `message_size_bytes`
- one future security sweep for `plaintext`, `tls`, and `mtls`

## Second-Phase Sweeps

After the initial plaintext sweep path works correctly, additional variables can be explored one at a time:

- `message_size`
- `producer_count`
- `partition_count`
- `batch_size`
- `acks`

These should be introduced only after the baseline matrix is stable.

## Reporting Guidance

The dissertation does not need to include every run the framework can perform. It should include:

- the baseline security sweep
- a justified subset of secondary sweeps
- enough repetition to support a credible interpretation
