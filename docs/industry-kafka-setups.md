# Industry Kafka Setups And Benchmark Parameter Ranges

## Purpose

This file records Kafka deployment patterns found in the dissertation source material and translates them into practical benchmark parameter ranges for the artefact.

The important methodological point is that most public company Kafka references describe scale and use case, not exact broker-level configuration. Therefore this file separates:

- **Directly sourced setup evidence**: what the source explicitly says.
- **Explicit numeric values**: values stated by the source.
- **Derived benchmark parameters**: practical experiment values inferred from the source evidence and Kafka configuration semantics.

This avoids pretending that every company publishes exact values for partitions, replication factor, compression, batch size, network latency, and TLS/mTLS configuration.

## Key Finding

Running every possible parameter combination is not practical for the dissertation. A full factorial design across security mode, partitions, replication factor, compression, batch size, message size, throughput, latency, broker count, and producer count would explode quickly.

The defensible approach is:

- Build a small set of **industry-inspired benchmark profiles**.
- Run each profile under `plaintext`, `TLS`, and `mTLS`.
- Calculate overhead as:

```text
TLS overhead  = (TLS metric - plaintext metric) / plaintext metric
mTLS overhead = (mTLS metric - plaintext metric) / plaintext metric
```

For throughput, lower is worse. For latency, higher is worse.

## Source Inventory Used

| Source | Local file | Type | Used for |
|---|---|---|---|
| Apache Kafka Powered By | `diss_sources/powered-by.html` | Kafka project company-use page | Real-world company use cases and scale statements |
| Meka 2025 | `diss_sources/Meka - 2025 - Financial Services Cloud Transformation Securing Sensitive Data in Kafka Event Streams.pdf` | Article | Financial-services Kafka security patterns and numeric performance/security claims |
| Apache Kafka producer configs | `diss_sources/producer-configs.html` | Kafka documentation | Producer parameter semantics and valid configuration fields |
| Apache Kafka broker configs | `diss_sources/broker-configs.html` | Kafka documentation | Broker/topic parameter semantics and valid configuration fields |
| Apache Kafka consumer configs | `diss_sources/consumer-configs.html` | Kafka documentation | Consumer parameter semantics and future consumer-side benchmark fields |
| Distributed systems enterprise source | `diss_sources/- - 2025 - Distributed Systems in Modern Enterprise Architecture Challenges and Solutions.pdf` | Article | Enterprise throughput, latency, resource-utilisation and network-latency framing |

## Directly Sourced Company And Sector Setups

| Setup label | Source evidence | Explicit scale or configuration | Relevant benchmark dimensions |
|---|---|---:|---|
| Financial-services secure Kafka | Meka 2025 says financial Kafka can sustain 2 million writes/s on three ZooKeeper servers and three brokers using 6-core, 32 GB RAM machines, with 99.99th percentile latency below 20 ms. It also states production financial clusters handle over 7 trillion messages/day with N+1 replication. | 3 brokers; 3 ZooKeeper servers; 6-core/32 GB machines; 2M writes/s; p99.99 < 20 ms; >7T messages/day; N+1 replication. | broker count, replication factor, throughput target, latency target, security mode, hardware sizing |
| Financial-services TLS deployment | Meka 2025 recommends TLS 1.3 with `TLS_AES_256_GCM_SHA384`, private subnet deployment, staged certificate validation, and multi-tier network design. | TLS 1.3; AES-256-GCM cipher; private subnet; 2.8% CPU overhead claim with hardware acceleration; 41.3% lower handshake latency than TLS 1.2 claim. | TLS vs plaintext, mTLS certificate overhead, private networking, handshake sensitivity |
| Financial-services encryption-at-rest and field encryption | Meka 2025 discusses AES-256-XTS volume encryption and AES-GCM 256-bit field-level encryption. It claims AES-256-XTS adds 3.2% latency to Kafka operations and field-level AES-GCM maintains 93.2% plaintext throughput. | AES-256-XTS; AES-GCM 256-bit; 3.2% latency overhead; 93.2% plaintext throughput retained. | encryption overhead framing, CPU overhead, storage overhead, non-transport-security caveat |
| Agoda travel data pipeline | Apache Kafka Powered By says Agoda runs trillions of events daily across multiple data centers. | Trillions of events/day; multiple data centers. | high-throughput analytics profile, multi-DC/multi-region profile |
| Aiven managed Kafka platform | Apache Kafka Powered By says Aiven provides Kafka as a managed service and uses it internally to run and monitor tens of thousands of clusters. | Tens of thousands of clusters. | managed-service/multi-tenant profile, many small-to-medium clusters rather than one huge cluster |
| Ants.vn production stream/log transfer | Apache Kafka Powered By says Ants.vn uses Kafka in production for stream processing and log transfer over 5B messages/month. | >5B messages/month. | log-transfer profile, medium sustained throughput |
| AppsFlyer event pipeline | Apache Kafka Powered By says AppsFlyer streams tens of billions of events daily. | Tens of billions of events/day. | high-volume event pipeline profile |
| Cloudflare log processing | Apache Kafka Powered By says Cloudflare collects hundreds of billions of events/day from thousands of servers. | Hundreds of billions of events/day; thousands of servers. | log analytics profile, high producer fan-in, compression, batching |
| Criteo business log collection | Apache Kafka Powered By says Criteo has tens of Kafka clusters across multiple data centres on three continents and processes up to 30M messages/s. | Tens of clusters; multiple data centres; three continents; up to 30M messages/s. | extreme throughput profile, multi-DC profile, replication/mirroring profile |
| Deep.BI real-time events | Apache Kafka Powered By says Deep.BI processes hundreds of thousands of real-time events/s. | Hundreds of thousands events/s. | mid/high real-time analytics profile |
| Grab mission-critical event logs | Apache Kafka Powered By says Grab supports TB/hour scale, mission-critical event logs, event sourcing, and stream processing across ride hailing, food delivery, and fintech. | TB/hour scale. | large-message/log-volume profile, mixed realtime and analytical consumers |
| Infobip CPaaS central pipeline | Apache Kafka Powered By says Infobip processes over 70B messages/month for real-time analytics and reporting. | >70B messages/month. | communications/event pipeline profile |
| ironSource game-growth events | Apache Kafka Powered By says ironSource processes millions of events/s and uses Kafka Streams for real-time use cases. | Millions of events/s. | high-throughput event profile, stream-processing profile |
| LINE service datahub | Apache Kafka Powered By says LINE produces hundreds of billions of messages daily for business logic, threat detection, search indexing, and analytics. | Hundreds of billions messages/day. | high-volume central datahub profile, multi-consumer workload |
| LinkedIn activity and metrics | Apache Kafka Powered By says LinkedIn uses Kafka for activity stream data and operational metrics powering products and offline analytics. | No exact numeric values in this local source. | activity-stream profile, metrics/log profile |
| MoEngage event streaming | Apache Kafka Powered By says MoEngage runs 25+ Kafka clusters processing over 1M messages/s across clusters. | 25+ clusters; >1M messages/s. | multi-cluster SaaS event-streaming profile |
| Zalando ESB/event streams | Apache Kafka Powered By says Zalando uses Kafka as an ESB to transition from monolith to microservices and enable near-real-time business intelligence. | No exact numeric values in this local source. | microservice event-bus profile |

## What The Sources Do Not Reveal

The local sources do **not** reliably disclose exact per-company values for:

- `num.partitions`
- per-topic partition counts
- exact `replication.factor`
- exact `min.insync.replicas`
- exact `compression.type`
- exact `batch.size`
- exact `linger.ms`
- exact producer count
- exact consumer group count
- exact network latency between brokers
- exact broker instance type for most companies
- exact TLS/mTLS certificate chain length or rotation period

Where these values are absent, the dissertation should not claim that a given company used a specific value. Instead, it can say that the artefact uses **industry-inspired parameter ranges** based on published deployment scale and Kafka configuration semantics.

## Parameter Ranges To Use In The Artefact

These ranges are practical for the dissertation and can be run under all three security modes.

| Parameter | Practical values | Rationale | Source basis |
|---|---:|---|---|
| `security_mode` | `plaintext`, `TLS`, `mTLS` | Required to measure transport-security overhead. | Dissertation research question; Meka TLS/mTLS security framing |
| `broker_count` | `3` initially; optionally `5` if budget allows | Three brokers support replication factor 3 and match the explicit financial benchmark setup. Five brokers gives a stronger scale-out comparison but costs more. | Meka 2025 explicit 3-broker benchmark |
| `replication_factor` | `1`, `2`, `3` | `1` shows no-replication baseline; `2` approximates N+1 for some failure tolerance; `3` is the common strong-durability baseline on a 3-broker cluster. | Meka 2025 N+1 replication; Kafka replication semantics |
| `min_insync_replicas` | `1`, `2` | Needed to evaluate durability/availability trade-offs with `acks=all`. | Kafka broker/topic semantics |
| `partition_count` | `1`, `3`, `6`, `12`, `24` | Captures single-partition ordering, moderate parallelism, and higher parallelism without creating too many small partitions for the dissertation budget. | Kafka partitioning semantics; high-throughput company use cases |
| `message_size_bytes` | `512`, `1024`, `10240`, `102400` | Captures small events, common log/message sizes, and larger payload/log records. Current validated values are `1024`, `10240`, `102400`. | Existing artefact sweep; event/log pipeline source use cases |
| `target_messages_per_second` | `1000`, `5000`, `10000` | Practical EC2-scale rates. Published company scales are much higher, but these values are feasible for controlled dissertation infrastructure. | Cloudflare/Criteo/LINE/MoEngage scale statements, scaled down |
| `compression_type` | `none`, `lz4`, `snappy`, `zstd` | Compression matters for log/event pipelines and TLS overhead because it changes bytes on the wire and CPU usage. | Kafka producer config semantics; event/log use cases |
| `batch_size` | `16384`, `65536`, `131072` | Tests default-ish batching versus larger batches. Larger batches can improve throughput but may affect latency. | Kafka producer config semantics |
| `linger_ms` | `0`, `5`, `20` | Tests no intentional batching delay, current baseline, and higher batching delay. | Kafka producer config semantics |
| `acks` | `1`, `all` | `acks=1` gives lower durability/latency; `acks=all` gives stronger durability and interacts with `min.insync.replicas`. | Kafka producer config semantics |
| `producer_count` | `1`, `3`, `6` | Tests single-client baseline and modest parallel producer fan-in. | Company fan-in/log-pipeline use cases, scaled down |
| `network_latency_ms` | `0`, `5`, `20`, `50` | Represents same-AZ/VPC, low WAN-like delay, and higher cross-region-like delay. Can be injected with `tc netem` later. | Distributed systems source highlights network latency sensitivity; Meka multi-region discussion |
| `num_records` | `100000` for exploratory; `1000000` for final selected profiles | Keeps exploratory runs cheap; final selected profiles should use longer runs for stability if budget allows. | Current artefact baseline; practical runtime control |

## Recommended Dissertation-Grade Benchmark Profiles

Instead of all combinations, run these profiles under `plaintext`, `TLS`, and `mTLS`.

### Profile 1: Financial-Secure Baseline

Inspired by Meka 2025 financial-services Kafka deployments.

| Parameter | Value |
|---|---:|
| `broker_count` | `3` |
| `replication_factor` | `3` |
| `min_insync_replicas` | `2` |
| `partitions` | `6` |
| `message_size_bytes` | `1024` |
| `compression_type` | `none` |
| `batch_size` | `16384` |
| `linger_ms` | `5` |
| `acks` | `all` |
| `target_messages_per_second` | `1000` |

### Profile 2: Log Analytics / High Fan-In

Inspired by Cloudflare, Criteo, Grab, LINE, and Infobip-style log/event pipelines.

| Parameter | Value |
|---|---:|
| `broker_count` | `3` |
| `replication_factor` | `3` |
| `min_insync_replicas` | `2` |
| `partitions` | `12` |
| `message_size_bytes` | `10240` |
| `compression_type` | `lz4` |
| `batch_size` | `65536` |
| `linger_ms` | `20` |
| `acks` | `all` |
| `target_messages_per_second` | `5000` |

### Profile 3: Large Payload / Telemetry Bulk

Inspired by TB/hour and large log-volume pipelines.

| Parameter | Value |
|---|---:|
| `broker_count` | `3` |
| `replication_factor` | `3` |
| `min_insync_replicas` | `2` |
| `partitions` | `12` |
| `message_size_bytes` | `102400` |
| `compression_type` | `zstd` |
| `batch_size` | `131072` |
| `linger_ms` | `20` |
| `acks` | `all` |
| `target_messages_per_second` | `1000` |

### Profile 4: Low-Latency Microservice Event Bus

Inspired by Zalando, Dream11, LinkedIn activity streams, and microservice event-bus use cases.

| Parameter | Value |
|---|---:|
| `broker_count` | `3` |
| `replication_factor` | `2` |
| `min_insync_replicas` | `1` |
| `partitions` | `6` |
| `message_size_bytes` | `1024` |
| `compression_type` | `none` |
| `batch_size` | `16384` |
| `linger_ms` | `0` |
| `acks` | `1` |
| `target_messages_per_second` | `5000` |

### Profile 5: Cross-Region / Network-Latency Sensitivity

Inspired by multi-data-center and multi-region source evidence from Agoda, Criteo, and Meka 2025.

| Parameter | Value |
|---|---:|
| `broker_count` | `3` |
| `replication_factor` | `3` |
| `min_insync_replicas` | `2` |
| `partitions` | `6` |
| `message_size_bytes` | `10240` |
| `compression_type` | `lz4` |
| `batch_size` | `65536` |
| `linger_ms` | `5` |
| `acks` | `all` |
| `target_messages_per_second` | `1000` |
| `network_latency_ms` | `0`, `5`, `20`, `50` |

## Suggested Experiment Matrix

The dissertation should run:

```text
5 profiles x 3 security modes x 3 trials = 45 benchmark runs
```

This is much more defensible than claiming to test “all possible values”. It covers realistic industry-inspired conditions while staying feasible on AWS.

If time or budget is tight, run:

```text
3 profiles x 3 security modes x 3 trials = 27 benchmark runs
```

Use profiles 1, 2, and 3 for the reduced matrix.

## How To Use This In The Dissertation

Recommended wording:

> Public case studies rarely disclose exact Kafka topic-level and producer-level configuration values. Therefore, this artefact uses industry-inspired benchmark profiles derived from published Kafka deployment descriptions and Kafka configuration semantics. Each profile captures a distinct class of real deployment: secure financial messaging, high-volume log analytics, large payload telemetry, low-latency microservice events, and network-latency-sensitive multi-region streaming. The same profiles are executed under plaintext, TLS, and mTLS to isolate transport-security overhead.

Avoid wording like:

> Cloudflare uses 12 partitions, lz4 compression, and 64 KB batches.

That is not supported by the local sources.

## Implication For Current Results

The current completed plaintext sweep only covers:

```text
security_mode = plaintext
variable = message_size_bytes
values = 1024, 10240, 102400
trials = 3
```

That result is useful as a pipeline validation and first baseline, but it is not enough for a high-mark final dissertation evaluation. The next stage should convert the profiles above into config files and run each one under `plaintext`, then repeat the same profiles under `TLS` and `mTLS`.
