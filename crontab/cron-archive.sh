#!/bin/bash
# script to archive this server on inactivity

if [ "$FOLLOWER" = true ] && [ "$RESTORING" = false ]; then
    uptime_seconds=$(awk '{print $1}' /proc/uptime);
    has_activity=$(bash /activity-check.sh);
    if [ "$has_activity" = false ] && [ $uptime_seconds -gt 600 ]; then
        echo "No activity detected, archiving server, but first let's try to restore";
        bash /restore-db.sh;
        
        server_id=$(bash /get-server-id-from-ip.sh $(curl -s ifconfig.me));
        if [ -z "$server_id" ]; then
            echo "ERROR: Server not found in clouding.io";
            exit 1;
        fi
        curl -X POST -H "Content-Type: application/json" -H "X-API-KEY: $CLOUDING_APIKEY" "https://api.clouding.io/v1/servers/$server_id/archive"
fi