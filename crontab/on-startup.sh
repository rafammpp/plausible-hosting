/cron-certbot.sh >> /logs/certbot-renew.log 2>&1;
/cron-restore.sh >> /logs/restore-script.log 2>&1;
/cron-logs-backup.sh >> /logs/logs-backup-script.log 2>&1;