#!/bin/bash
#script coleta a posicao de 3 dias do bucket baseado no profile

set -euo pipefail
set +x

OUTPUT_FILE="${CSV_DIR}/aws_s3_bucket_size.csv"

echo "profile_discovery,bucket_name,region,size_gb" > "${OUTPUT_FILE}"

total_size=0

for profile in $(aws configure list-profiles); do
  buckets=$(aws s3api list-buckets --profile "$profile" --query "Buckets[].Name" --output text)
  for bucket in $buckets; do
    region=$(aws s3api get-bucket-location --bucket "$bucket" --profile "$profile" --output text 2>/dev/null)
    if [ "$region" == "None" ] || [ -z "$region" ]; then region="us-east-1"; fi

    start_time=$(date -u -v-3d +%Y-%m-%dT%H:%M:%SZ)
    end_time=$(date -u -v-1d +%Y-%m-%dT%H:%M:%SZ)

    size_bytes=$(aws cloudwatch get-metric-statistics \
      --namespace AWS/S3 \
      --metric-name BucketSizeBytes \
      --start-time "$start_time" \
      --end-time "$end_time" \
      --period 86400 \
      --statistics Average \
      --dimensions Name=BucketName,Value=$bucket Name=StorageType,Value=StandardStorage \
      --region "$region" \
      --profile "$profile" \
      --query "Datapoints[0].Average" \
      --output text 2>/dev/null)

    if [[ "$size_bytes" != "None" && "$size_bytes" != "" ]]; then
      size_gb=$(echo "scale=2; $size_bytes / 1024 / 1024 / 1024" | bc)
      echo "$profile,$bucket,$region,$size_gb" >> "${OUTPUT_FILE}"

      # Soma incremental
      total_size=$(echo "$total_size + $size_gb" | bc)
    fi
  done
done

# Linha final com o total
echo "TOTAL,,,$total_size" >> "${OUTPUT_FILE}"

echo "✔️ Arquivo CSV gerado com total em: ${OUTPUT_FILE}"
