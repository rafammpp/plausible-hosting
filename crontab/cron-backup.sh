source /run/secrets/plausible-conf;
# Check if is a follower server or not (follower servers don't need to backup)
if [ "$FOLLOWER" = true ] ; then
    echo "This is a follower server, skipping backup";
    exit 0;
fi

bash /backup-db.sh;