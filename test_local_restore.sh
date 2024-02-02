docker compose exec crontab clickhouse-client -h plausible_events_db --query "DROP DATABASE IF EXISTS test_restore";
docker compose exec crontab clickhouse-client -h plausible_events_db --query "CREATE DATABASE test_restore";
docker compose exec crontab clickhouse-client -h plausible_events_db --query "RESTORE DATABASE plausible_events_db as test_restore FROM Disk('backup_disk', 'plausible_events_db-2024-02-02-040000.zip')";