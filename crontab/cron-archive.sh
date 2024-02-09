#!/bin/bash
source /run/secrets/plausible-conf;
if [ "$DISABLE_CRON_SCRIPTS" = true ] ; then
    exit 0;
fi
# script to archive this server on inactivity
echo "Started at $(date +%Y-%m-%d-%H%M%S)";

if [ "$FOLLOWER" = true ] && [ ! -f /tmp/restore-db.lock ]; then
    uptime_seconds=$(awk '{print int($1)}' /proc/uptime);
    has_activity=$(bash /activity-check.sh);
    if [ "$has_activity" = false ] && [ $uptime_seconds -gt 600 ]; then
        echo "No activity detected, archiving server, but first let's try to restore";
        bash /restore-db.sh;

        server_id=$(bash /get-server-id-from-ip.sh $(curl -s ifconfig.me));
        if [ -z "$server_id" ]; then
            echo "ERROR: Server not found in clouding.io";
            exit 1;
        fi
        curl -s -X POST -H "Content-Type: application/json" -H "X-API-KEY: $CLOUDING_APIKEY" "https://api.clouding.io/v1/servers/$server_id/archive"
    fi
else 
    exit 0;
fi
