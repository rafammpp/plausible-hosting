FROM clickhouse/clickhouse-server:24.12-alpine

RUN apk update
RUN apk add --no-cache --update curl coreutils postgresql-client aws-cli

# Copy cron file to the container
COPY ./table/cron /etc/cron.d/cron

# Copy the cron scripts to the container
COPY ./scripts/ /scripts/

# Give permissions
RUN chmod 0644 /etc/cron.d/cron && chmod +x /scripts/*
 
# Add the cron job
RUN crontab /etc/cron.d/cron

# Run the cron service in the foreground
CMD /scripts/on-startup.sh; crond -l 2 -L /var/log/cron.log -f;