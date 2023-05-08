#!/bin/bash
# check if aws cli is installed
if ! [ -x "$(command -v aws)" ]; then
  echo 'Error: aws cli is not installed.' >&2
  exit 1
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR;

source plausible-conf.env;

# Variables
BACKUP_DIR=backup
PLAUSIBLE_CONTAINER=plausible
POSTGRES_CONTAINER=plausible_db
CLICKHOUSE_CONTAINER=plausible_events_db
# Create backup directory
mkdir -p $BACKUP_DIR/postgres;
mkdir -p $BACKUP_DIR/clickhouse;

chmod -R 777 $BACKUP_DIR;

docker compose stop $PLAUSIBLE_CONTAINER;

docker exec $POSTGRES_CONTAINER sh -c "pg_dump -U postgres plausible_db --format=tar > /backup/plausible_db-$(date +%Y-%m-%d-%H%M%S).tar";

docker exec $CLICKHOUSE_CONTAINER sh -c "clickhouse-client --query \"BACKUP DATABASE plausible_events_db TO Disk('backup_disk', 'db.zip')\" && chmod 777 /backup/db.zip";

docker compose start $PLAUSIBLE_CONTAINER;

mv $BACKUP_DIR/clickhouse/db.zip $BACKUP_DIR/clickhouse/plausible_events_db-$(date +%Y-%m-%d-%H%M%S).zip;

# Upload backups to S3
aws s3 cp $BACKUP_DIR s3://$S3_BUCKET/plausible --recursive;

# delete local backups
find $BACKUP_DIR -type f -delete;