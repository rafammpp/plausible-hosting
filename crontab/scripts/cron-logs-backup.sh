#!/bin/bash
source /run/secrets/plausible-conf;
if [ "$DISABLE_CRON_SCRIPTS" = true ] || [ -f /locks/setting-up.lock ]; then
    exit 0;
fi

if [ "$FOLLOWER" = true ] ; then
    echo "Started at $(date +%Y-%m-%d-%H%M%S)";
    bash /scripts/backup-logs.sh;
    exit 0;
fi