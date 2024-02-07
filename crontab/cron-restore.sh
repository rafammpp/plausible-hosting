#!/bin/bash
source /run/secrets/plausible-conf;

# Check if is a follower server or not (non follower servers don't restore) Default is non follower
if [ "$FOLLOWER" = false ] || [ -z "$FOLLOWER" ]; then 
    echo "This is not a follower server, skipping restore";
else
    bash /restore-db.sh;
fi
