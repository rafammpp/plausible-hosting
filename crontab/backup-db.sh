#!/bin/bash
source /run/secrets/plausible-conf;

mkdir -p /backup/postgres;
mkdir -p /backup/clickhouse;
mkdir -p /backup/logs;

chmod -R 777 /backup;
echo "Backup started at $(date +%Y-%m-%d-%H%M%S)";
pg_dump -h plausible_db plausible_db --format=tar > /backup/postgres/plausible_db-$(date +%Y-%m-%d-%H%M%S).tar;
clickhouse-client --host plausible_events_db --query "BACKUP DATABASE plausible_events_db TO Disk('backup_disk', 'db')";

mv /backup/clickhouse/db /backup/clickhouse/plausible_events_db-$(date +%Y-%m-%d-%H%M%S);

echo "Uploading backups to R2";
# Upload backups to R2
aws s3 cp /backup s3://$R2_BUCKET/$SERVER_NAME --recursive --only-show-errors --endpoint-url $R2_ENDPOINT;

# Upload logs to R2
mv -f -t /logs/* /backup/logs/;
mv /var/log/cron.log /backup/logs/cron-$(date +%Y-%m-%d-%H%M%S).log;

aws s3 cp /backup/logs s3://$R2_BUCKET/$SERVER_NAME/logs/$(date +%Y-%m-%d-%H%M%S) --recursive --no-progress --endpoint-url $R2_ENDPOINT;

# delete local backups
find /backup -type f -delete;
find /backup/clickhouse/* -type d -delete;

echo "Backup finished at $(date +%Y-%m-%d-%H%M%S)";