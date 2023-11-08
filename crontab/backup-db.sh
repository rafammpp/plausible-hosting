#!/bin/bash
source /run/secrets/plausible-conf;

mkdir -p /backup/postgres;
mkdir -p /backup/clickhouse;

chmod -R 777 /backup;

pg_dump -h plausible_db plausible_db --format=tar > /backup/plausible_db-$(date +%Y-%m-%d-%H%M%S).tar;

clickhouse-client --query "BACKUP DATABASE plausible_events_db TO Disk('backup_disk', 'db.zip')";
chmod 777 /backup/db.zip;

mv /backup/clickhouse/db.zip /backup/clickhouse/plausible_events_db-$(date +%Y-%m-%d-%H%M%S).zip;

# Upload backups to S3
aws s3 cp /backup s3://$R2_BUCKET/$SERVER_NAME --recursive --endpoint-url $R2_ENDPOINT;

# delete local backups
find /backup -type f -delete;