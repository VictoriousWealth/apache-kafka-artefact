# Orchestration Scripts

These scripts connect Terraform provisioning and Kafka bootstrap into a simple remote deployment flow.

## Current Flow

1. `export_tf_outputs.sh`
   Save Terraform outputs to `.orchestration/terraform-output.json`

2. `build_inventory.sh`
   Convert Terraform outputs into an inventory of broker and client IPs

3. `build_cluster_metadata.sh`
   Derive the KRaft quorum voter string

4. `bootstrap_brokers.sh`
   Copy bootstrap assets to broker nodes, install Kafka, configure plaintext KRaft, and start Kafka

5. `prepare_benchmark_client.sh`
   Install baseline dependencies on the benchmark client node

6. `deploy_plaintext_cluster.sh`
   Run the full plaintext deployment flow with step checkpoints so interrupted runs can be resumed

## Requirements

- `terraform`
- `jq`
- `ssh`
- `scp`
- access to the EC2 instances via an SSH key

## Notes

The current scripts assume:

- Terraform has already applied successfully
- all broker nodes are Ubuntu-based and reachable over SSH
- the SSH user is `ubuntu` unless overridden
- the first target is plaintext-only deployment

## Hardening Features

- retry handling for transient command failures
- atomic writes for generated local state files
- resumable checkpoints for the top-level plaintext deployment flow
- broker service health checks after startup
