#!/bin/bash
source /run/secrets/plausible-conf;
if [ "$DISABLE_CRON_SCRIPTS" = true ] ; then
    exit 0;
fi

if [ "$FOLLOWER" = true ] ; then
    echo "Started at $(date +%Y-%m-%d-%H%M%S)";
    bash /backup-logs.sh;
    exit 0;
fi