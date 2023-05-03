# restore last backup stored in s3 bucket to a docker postgres and clickhouse container

# check if aws cli is installed
if ! [ -x "$(command -v aws)" ]; then
  echo 'Error: aws cli is not installed.' >&2
  exit 1
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR;

# Variables
BACKUP_DIR=backup
S3_BUCKET=backups-hostinger
POSTGRES_CONTAINER=plausible_db
CLICKHOUSE_CONTAINER=plausible_events_db

# Create backup directory
mkdir -p $BACKUP_DIR/postgres
mkdir -p $BACKUP_DIR/clickhouse

chmod -R 777 $BACKUP_DIR

# Download last backups from S3
last_postgres_bk=$( aws s3 ls s3://backups-hostinger/plausible/postgres/ | sort | tail -n 1 | awk '{print $4}' );
aws s3 cp s3://backups-hostinger/plausible/postgres/$last_postgres_bk $BACKUP_DIR/postgres/$last_postgres_bk;

last_clickhouse_bk=$( aws s3 ls s3://backups-hostinger/plausible/clickhouse/ | sort | tail -n 1 | awk '{print $4}' );
aws s3 cp s3://backups-hostinger/plausible/clickhouse/$last_clickhouse_bk $BACKUP_DIR/clickhouse/$last_clickhouse_bk;

docker compose down --remove-orphans;
docker compose up $POSTGRES_CONTAINER $CLICKHOUSE_CONTAINER -d;

# Wait for containers to start
sleep 10;

# Restore postgres backup
docker exec $POSTGRES_CONTAINER dropdb -U postgres plausible_db;
docker exec $POSTGRES_CONTAINER createdb -U postgres plausible_db;
docker exec $POSTGRES_CONTAINER pg_restore -U postgres -d plausible_db /backup/$last_postgres_bk;

# Restore clickhouse backup/opusdei.org
docker exec $CLICKHOUSE_CONTAINER clickhouse-client --query "DROP DATABASE plausible_events_db";
docker exec $CLICKHOUSE_CONTAINER clickhouse-client --query "CREATE DATABASE plausible_events_db";
docker exec $CLICKHOUSE_CONTAINER clickhouse-client --query "RESTORE DATABASE plausible_events_db FROM Disk('backup_disk', '$last_clickhouse_bk')";

docker compose up -d;

# delete local backups
find $BACKUP_DIR -type f -delete
