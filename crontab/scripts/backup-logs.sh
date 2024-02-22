#!/bin/bash
source /run/secrets/plausible-conf;

# Upload logs to R2 and reset log files
cp -f -r  /logs /backup/logs;
find /logs -type f -exec sh -c '>"{}"' \;

# backup cron logs and reset them
mv /var/log/cron.log /backup/logs/cron-$(date +%Y-%m-%d-%H%M%S).log;
echo "" > /var/log/cron.log;

aws s3 cp /backup/logs s3://$R2_BUCKET/$BACKUP_TO_SERVER_NAME/logs/$(date +%Y-%m-%d-%H%M%S) --recursive --no-progress --endpoint-url $R2_ENDPOINT --region auto;

# delete local backups
find /backup -type f -delete;
