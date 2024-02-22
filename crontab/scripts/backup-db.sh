#!/bin/bash
source /run/secrets/plausible-conf;

if [ -z "$R2_BUCKET" ]; then
    echo "R2_BUCKET is not set";
    exit 1;
fi

if [ -z "$R2_ENDPOINT" ]; then
    echo "R2_ENDPOINT is not set";
    exit 1;
fi

if [ -z "$BACKUP_TO_SERVER_NAME" ]; then
    echo "BACKUP_TO_SERVER_NAME is not set";
    exit 1;
fi

export PGUSER=postgres
export PGPASSWORD=postgres

mkdir -p /backup/postgres;
mkdir -p /backup/clickhouse;
mkdir -p /backup/logs;

chmod -R 777 /backup;
echo "Backup started at $(date +%Y-%m-%d-%H%M%S)";
pg_dump -h plausible_db plausible_db --format=tar > /backup/postgres/plausible_db-$(date +%Y-%m-%d-%H%M%S).tar;

# Check all tables before backing up
clickhouse-client --host plausible_events_db --query "CHECK ALL TABLES FORMAT PrettyCompactMonoBlock SETTINGS check_query_single_value_result = 0";

clickhouse-client --host plausible_events_db --query "BACKUP DATABASE plausible_events_db TO Disk('backup_disk', 'db.zip')";

mv /backup/clickhouse/db.zip /backup/clickhouse/plausible_events_db-$(date +%Y-%m-%d-%H%M%S).zip;

echo "Uploading backups to R2";
# Upload backups to R2
aws s3 cp /backup s3://$R2_BUCKET/$BACKUP_TO_SERVER_NAME --recursive --only-show-errors --endpoint-url $R2_ENDPOINT --region auto;

bash /scripts/backup-logs.sh;

echo "Backup finished at $(date +%Y-%m-%d-%H%M%S)";