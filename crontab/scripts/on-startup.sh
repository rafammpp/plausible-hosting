/scripts/cron-certbot.sh >> /logs/certbot-renew.log 2>&1;
/scripts/cron-restore.sh >> /logs/restore-script.log 2>&1;
/scripts/cron-logs-backup.sh >> /logs/logs-backup-script.log 2>&1;