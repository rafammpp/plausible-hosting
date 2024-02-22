#!/bin/bash
source /run/secrets/plausible-conf;
if [ "$AUTO_RESIZE_DISK" = false ] || [ -z "$AUTO_RESIZE_DISK" ]; then
    exit 0;
fi
# exit if there is no backup size
if [ -z "$1" ]; then
    echo "Backup size not provided";
    exit 1;
fi

# Get the current disk available space in bytes
current_disk_space=$(df --output=avail /logs | tail -n 1);

# the needed space in bytes is three time the backup size, it will be passed as argument
needed_space=$(($1 * 3));


# if the current disk space is less than the needed space, resize the disk
if [ $current_disk_space -lt $needed_space ]; then
    echo "Resizing disk";
    server_id=$(bash /scripts/get-server-id-from-ip.sh $(curl -s ifconfig.me));
    if [ -z "$server_id" ]; then
        echo "ERROR: Server not found in clouding.io";
        exit 1;
    fi
    space_to_add_GB=$(($1 * 4 / 1024 / 1024 / 1024));
    current_disk_size_GB=$(bash /scripts/get-server-current-size.sh $server_id);
    if [ -z "$current_disk_size_GB" ]; then
        echo "ERROR: Server disk size not found in clouding.io";
        exit 1;
    fi

    new_disk_size=$(($current_disk_size_GB + $space_to_add_GB));

    # remove restore lock before resizing disk
    if [ -f /locks/restore-db.lock ]; then
        rm /locks/restore-db.lock;
    fi

    curl -X POST -H "Content-Type: application/json" -H "X-API-KEY: $CLOUDING_APIKEY" -d "{\"volumeSizeGb\": \"$new_disk_size\"}" "https://api.clouding.io/v1/servers/$server_id/resize";
fi
