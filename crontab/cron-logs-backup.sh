#!/bin/bash
if [ "$DISABLE_CRON_SCRIPTS" = true ] ; then
    exit 0;
fi

source /run/secrets/plausible-conf;

if [ "$FOLLOWER" = true ] ; then
    bash /backup-logs.sh;
    exit 0;
fi