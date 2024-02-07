source /run/secrets/plausible-conf;
# Check if is a follower server or not (follower servers don't need to backup)
if [ "$FOLLOWER" = true ] ; then
    echo "This is a follower server, skipping backup";
    exit 0;
fi

bash /backup-db.sh;

# if has a follower to unarchive, do it. the var is FOLLWER_TO_WAKEUP, and it's the ip of the follower server
if [ -n "$FOLLOWER_TO_WAKEUP" ]; then
    echo "Waking up follower server";
    server_id=$(bash /get-server-id-from-ip.sh $FOLLOWER_TO_WAKEUP);
    if [ -z "$server_id" ]; then
        echo "ERROR: Server not found in clouding.io";
        exit 1;
    fi
    curl -X POST -H "Content-Type: application/json" -H "X-API-KEY: $CLOUDING_APIKEY" -d '{"server_id": "'$server_id'"}' "https://api.clouding.io/v1/servers/$server_id/unarchive";
fi
