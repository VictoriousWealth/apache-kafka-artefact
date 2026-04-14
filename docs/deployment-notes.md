# Deployment Notes

## Initial Environment Baseline

The first implementation target is a modest AWS EC2 environment intended to validate the framework before larger runs are attempted.

Initial assumptions:

- region: `eu-west-2`
- image family: `Ubuntu 24.04 LTS`
- broker count: `3`
- benchmark client count: `1`
- instance type: `t3.large`

This is a pragmatic baseline for development, not yet a final claim about optimal Kafka hardware.

## Why This Baseline

- it is cheap enough to iterate on
- it is strong enough to host a small Kafka cluster and a separate benchmark client
- it keeps machine specifications explicit, which helps the dissertation methodology

## Expected Evolution

The infrastructure may later move to:

- larger instance types
- separate private subnets
- EBS tuning
- additional monitoring or metrics agents

Those changes should be introduced only after the baseline plaintext framework is working end to end.
