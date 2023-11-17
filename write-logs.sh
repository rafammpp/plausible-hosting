mkdir -p docker-compose-logs;
for s in $(docker compose ps --services); do
    docker compose logs $s > docker-compose-logs/$s-$(date +%F-%N).log;    
done
docker compose logs > docker-compose-logs/all-aggregated-$(date +%F-%N).log;
