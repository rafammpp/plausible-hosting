source /run/secrets/plausible-conf;
# Check if is a follower server or not (non follower servers don't restore)
if [ "$FOLLOWER" = false ] ; then
    echo "This is not a follower server, skipping restore";
    exit 0;
fi

bash /restore-db.sh;