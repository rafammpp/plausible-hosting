FROM clickhouse/clickhouse-server:22.6-alpine

RUN apk update
RUN apk add --no-cache postgresql-client aws-cli nginx certbot certbot-nginx 

# Copy cron file to the container
COPY ./table/cron /etc/cron.d/cron

# Copy backup script to the container
COPY ./backup-db.sh /backup-db.sh 

# Copy restore script to the container
COPY ./restore-db.sh /restore-db.sh

# Copy the cron scripts to the container
COPY ./cron-backup.sh /cron-backup.sh
COPY ./cron-restore.sh /cron-restore.sh

# Give the permission
RUN chmod 0644 /etc/cron.d/cron && chmod +x /backup-db.sh /restore-db.sh /cron-backup.sh /cron-restore.sh
 
# Add the cron job
RUN crontab /etc/cron.d/cron
 
# Run the cron service in the foreground
CMD [ "crond", "-l", "2", "-L", "/var/log/cron.log", "-f" ]
