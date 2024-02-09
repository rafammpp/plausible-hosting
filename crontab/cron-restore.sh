#!/bin/bash
source /run/secrets/plausible-conf;
if [ "$DISABLE_CRON_SCRIPTS" = true ] ; then
    exit 0;
fi

# Check if is a follower server or not (non follower servers don't restore) Default is non follower
if [ "$FOLLOWER" = false ] || [ -z "$FOLLOWER" ]; then 
    echo "This is not a follower server, skipping restore";
else
    echo "Started at $(date +%Y-%m-%d-%H%M%S)";
    bash /restore-db.sh;
fi
