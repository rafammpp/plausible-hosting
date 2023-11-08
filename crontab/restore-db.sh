#!/bin/bash
# restore last backup stored in s3 bucket to a docker postgres and clickhouse container
source /run/secrets/plausible-conf;

# Create backup directory
mkdir -p /backup/postgres;
mkdir -p /backup/clickhouse;

chmod -R 777 /backup;


# Download last backups from S3
last_postgres_bk=$( aws s3 ls s3://$R2_BUCKET/$SERVER_NAME/postgres/ --endpoint-url $R2_ENDPOINT | sort | tail -n 1 | awk '{print $4}' );
aws s3 cp s3://$R2_BUCKET/$SERVER_NAME/postgres/$last_postgres_bk /backup/postgres/$last_postgres_bk --endpoint-url $R2_ENDPOINT;

last_clickhouse_bk=$( aws s3 ls s3://$R2_BUCKET/$SERVER_NAME/clickhouse/ --endpoint-url $R2_ENDPOINT | sort | tail -n 1 | awk '{print $4}' );
aws s3 cp s3://$R2_BUCKET/$SERVER_NAME/clickhouse/$last_clickhouse_bk /backup/clickhouse/$last_clickhouse_bk --endpoint-url $R2_ENDPOINT;

# Restore postgres backup
# dropdb -U postgres plausible_db;
# createdb -U postgres plausible_db;
pg_restore -h plausible_db -d plausible_db --clean /backup/$last_postgres_bk;

# Restore clickhouse backup/opusdei.org
clickhouse-client -h plausible_events_db --query "DROP DATABASE plausible_events_db";
clickhouse-client -h plausible_events_db --query "CREATE DATABASE plausible_events_db";
clickhouse-client -h plausible_events_db --query "RESTORE DATABASE plausible_events_db FROM Disk('backup_disk', '$last_clickhouse_bk')";

# delete local backups
find /backup -type f -delete
