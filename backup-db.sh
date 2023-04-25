#!/bin/bash
# check if aws cli is installed
if ! [ -x "$(command -v aws)" ]; then
  echo 'Error: aws cli is not installed.' >&2
  exit 1
fi


# Variables
BACKUP_DIR=plausible-backups
S3_BUCKET=your-bucket-name
POSTGRES_CONTAINER=plausible_db
CLICKHOUSE_CONTAINER=plausible_events_db
# Create backup directory
mkdir -p $BACKUP_DIR/postgres
mkdir -p $BACKUP_DIR/clickhouse


docker compose exec $POSTGRES_CONTAINER sh -c "pg_dump -U postgres plausible_db > /backup/plausible_db-$(date +%Y-%m-%d).bak"

# TODO we need clickhouse backup image
docker compose exec $CLICKHOUSE_CONTAINER sh -c "clickhouse-backup > /backup/clickhouse-$(date +%Y-%m-%d).tar.gz"

# # Upload backups to S3
# aws s3 cp $BACKUP_DIR s3://$S3_BUCKET --recursive

# # delete local backups
# rm -rf $BACKUP_DIR
