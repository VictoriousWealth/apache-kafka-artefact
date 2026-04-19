# Thesis Mapping

## Purpose

This document maps the artefact design to the dissertation structure and the marking constraints described in `uni_rules`.

## Rubric Alignment

### Quality of Product

The artefact supports this through:

- a non-trivial distributed systems test environment
- multiple Kafka security configurations
- automated experiment execution
- structured result generation
- resumable factorial benchmark execution for matched plaintext, TLS, and mTLS parameter spaces

### Quality of Process

The artefact supports this through:

- controlled one-factor-at-a-time methodology for early validation
- repeatable benchmark baselines, sweeps, final factorial plans, and targeted consumer validation plans
- explicit baseline and sweep definitions
- traceable outputs and documentation

## Rule Mapping

### Real-World Compliance

Addressed by:

- realistic Kafka configuration on dedicated VM instances
- explicit security modes
- support for topics, partitions, and replication
- documented rationale for TLS and mTLS

### Evaluating Trade-offs

Addressed by:

- direct comparison of `plaintext`, `TLS`, and `mTLS`
- fixed baselines with controlled changes
- throughput-first evaluation

### Benchmarking Restrictions

Addressed by:

- throughput as the primary metric
- controlled parameter sweeps and explicitly documented factorial subsets
- transparent baseline, sweep, and factorial definitions

### Data and Ethics Restrictions

Addressed by:

- use of technical benchmark traffic only
- no requirement for human-subject data

## Dissertation Chapter Mapping

### Chapter 2: Literature Review

This chapter should justify:

- why Kafka performance is sensitive to transport-level overhead
- why TLS and mTLS are relevant zero-trust-aligned controls
- why controlled benchmarking is necessary

### Chapter 3: Design, Implementation, and Testing

This chapter should explain:

- architecture of the artefact
- deployment setup
- security modes
- workload generation
- experiment controller design
- measurement process
- fairness and validity controls

### Chapter 4: Results and Discussion

This chapter should present:

- throughput comparisons
- latency comparisons
- selected parameter sweeps
- selected factorial slices where they add explanatory value
- interpretation of observed trade-offs

### Chapter 5: Evaluation, Conclusions, and Further Work

This chapter should evaluate:

- whether the artefact answered the research question
- limitations of the current deployment and measurements
- future improvements such as richer metrics, larger clusters, or additional security controls

## Implementation Priority Mapping

The first implementation milestone should support Chapter 3 directly:

1. plaintext Kafka deployment
2. TLS deployment
3. mTLS deployment
4. workload runner
5. automated experiment execution
6. results persistence

That sequence gives the dissertation a defensible methodology even before the full evaluation is complete.
