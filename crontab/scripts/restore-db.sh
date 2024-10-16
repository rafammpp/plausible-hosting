#!/bin/bash
# restore last backup stored in r2 bucket to a docker postgres and clickhouse container
# setup a semaphore to avoid multiple restores at the same time

function cleanup {
    echo "Removing locks"
    rm /locks/restore-db.lock;
    rm /locks/archive.lock;
}

if [ -f /locks/restore-db.lock ]; then
    echo "Restore already in progress or locked. Exiting...";
    exit 1;
else
    touch /locks/restore-db.lock;
    touch /locks/archive.lock;
fi

trap cleanup EXIT;

source /run/secrets/plausible-conf;
export PGUSER=postgres
export PGPASSWORD=postgres

# first positional parameter is optional and can be the R2 folder name
if [ -n "$1" ]; then
    export RESTORE_FROM_SERVER_NAME=$1;
fi

# check if RESTORE_FROM_SERVER_NAME is set
if [ -z "$RESTORE_FROM_SERVER_NAME" ]; then
    echo "RESTORE_FROM_SERVER_NAME is not set";
    exit 1;
fi
# check if R2_BUCKET is set
if [ -z "$R2_BUCKET" ]; then
    echo "R2_BUCKET is not set";
    exit 1;
fi
# check if R2_ENDPOINT is set
if [ -z "$R2_ENDPOINT" ]; then
    echo "R2_ENDPOINT is not set";
    exit 1;
fi


# Create backup directory
mkdir -p /backup/postgres;
mkdir -p /backup/clickhouse;

chmod -R 777 /backup;

restored_postgres_bk=$(cat /last_bks/postgres.txt);
restored_clickhouse_bk=$(cat /last_bks/clickhouse.txt);

# Download last backups from r2
last_postgres_bk=$( aws s3 ls s3://$R2_BUCKET/$RESTORE_FROM_SERVER_NAME/postgres/ --endpoint-url $R2_ENDPOINT --region auto | sort | tail -n 1 | awk '{print $4}' );
if [[ $last_postgres_bk == $restored_postgres_bk ]]; then
    echo "No new postgres backup to restore";
else
    aws s3 cp s3://$R2_BUCKET/$RESTORE_FROM_SERVER_NAME/postgres/$last_postgres_bk /backup/postgres/$last_postgres_bk --only-show-errors --endpoint-url $R2_ENDPOINT --region auto;
    # Restore postgres backup
    dropdb --force -h plausible_db plausible_db;
    createdb -h plausible_db plausible_db;
    pg_restore -h plausible_db -d plausible_db /backup/postgres/$last_postgres_bk;
fi


# Restore clickhouse backup, zip format
last_clickhouse_bk=$( aws s3 ls s3://$R2_BUCKET/$RESTORE_FROM_SERVER_NAME/clickhouse/ --endpoint-url $R2_ENDPOINT --region auto | sort | tail -n 1 | awk '{print $4}' );

if [[ $last_clickhouse_bk == $restored_clickhouse_bk ]]; then
    echo "No new clickhouse backup to restore";
else
    # get backup size before download
    bk_size=$(aws s3 ls s3://$R2_BUCKET/$RESTORE_FROM_SERVER_NAME/clickhouse/$last_clickhouse_bk --endpoint-url $R2_ENDPOINT --region auto | awk '{print $3}');
    bash /scripts/resize-disk.sh $bk_size;
    if [ $? -ne 0 ]; then
        echo "Error resizing disk";
        exit 1;
    fi

    aws s3 cp s3://$R2_BUCKET/$RESTORE_FROM_SERVER_NAME/clickhouse/$last_clickhouse_bk /backup/clickhouse/$last_clickhouse_bk --only-show-errors --endpoint-url $R2_ENDPOINT --region auto;
    # if the command exit status code is not 0, the script will exit with status 1
    if [ $? -ne 0 ]; then
        echo "Error downloading clickhouse backup";
        exit 1;
    fi

    # Restore clickhouse backup
    clickhouse-client -h plausible_events_db --query "DROP DATABASE plausible_events_db";
    clickhouse-client -h plausible_events_db --query "CREATE DATABASE plausible_events_db";
    clickhouse-client -h plausible_events_db --query "RESTORE DATABASE plausible_events_db FROM Disk('backup_disk', '$last_clickhouse_bk')";
fi

# delete local backups
find /backup -type f -delete

echo $last_postgres_bk > /last_bks/postgres.txt;
echo $last_clickhouse_bk > /last_bks/clickhouse.txt;
