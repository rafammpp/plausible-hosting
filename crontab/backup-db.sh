#!/bin/bash
source /run/secrets/plausible-conf;
export PGUSER=postgres
export PGPASSWORD=postgres

mkdir -p /backup/postgres;
mkdir -p /backup/clickhouse;
mkdir -p /backup/logs;

chmod -R 777 /backup;
echo "Backup started at $(date +%Y-%m-%d-%H%M%S)";
pg_dump -h plausible_db plausible_db --format=tar > /backup/postgres/plausible_db-$(date +%Y-%m-%d-%H%M%S).tar;

# Check all tables before backing up
# clickhouse-client --host plausible_events_db --query "CHECK ALL TABLES FORMAT PrettyCompactMonoBlock SETTINGS check_query_single_value_result = 0";

clickhouse-client --host plausible_events_db --query "BACKUP DATABASE plausible_events_db TO Disk('backup_disk', 'db.zip')";

mv /backup/clickhouse/db.zip /backup/clickhouse/plausible_events_db-$(date +%Y-%m-%d-%H%M%S).zip;

echo "Uploading backups to R2";
# Upload backups to R2
aws s3 cp /backup s3://$R2_BUCKET/$SERVER_NAME --recursive --only-show-errors --endpoint-url $R2_ENDPOINT;

# Upload logs to R2 and reset log files
cp -f -r  /logs /backup/logs;
find /logs -type f -exec sh -c '>"{}"' \;

# backup cron logs and reset them
mv /var/log/cron.log /backup/logs/cron-$(date +%Y-%m-%d-%H%M%S).log;
echo "" > /var/log/cron.log;

aws s3 cp /backup/logs s3://$R2_BUCKET/$SERVER_NAME/logs/$(date +%Y-%m-%d-%H%M%S) --recursive --no-progress --endpoint-url $R2_ENDPOINT;

# delete local backups
find /backup -type f -delete;
find /backup/clickhouse/* -type d -delete;

echo "Backup finished at $(date +%Y-%m-%d-%H%M%S)";