#!/bin/bash
source /run/secrets/plausible-conf;
if [ "$DISABLE_CRON_SCRIPTS" = true ] ; then
    exit 0;
fi

if [ "$FOLLOWER" = true ] ; then
    bash /backup-logs.sh;
    exit 0;
fi