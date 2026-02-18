#!/usr/bin/env bash
set -e

export $(grep -v '^#' ../.env | xargs)

SCALES=("baixa" "media" "alta" "big")

for SCALE in "${SCALES[@]}"; do
    aws s3 cp s3://${BUCKET_NAME}/dumps/sysbench_prepare_$SCALE.tar.gz ../dumps/sysbench_prepare_$SCALE.tar.gz --profile tcc
done
