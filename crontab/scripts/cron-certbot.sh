#!/bin/bash
source /run/secrets/plausible-conf;
if [ "$DISABLE_CRON_SCRIPTS" = true ] ; then
    exit 0;
fi

/usr/bin/certbot renew --quiet;