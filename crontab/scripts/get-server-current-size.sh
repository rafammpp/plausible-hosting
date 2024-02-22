#!/bin/bash
source /run/secrets/plausible-conf;

server_id=$1;

if [ -z "$server_id" ] || [ -z "$CLOUDING_APIKEY" ]; then
    exit 1;
fi

current_disk_size=$(curl -s -X GET -H "Content-Type: application/json" -H "X-API-KEY: $CLOUDING_APIKEY" "https://api.clouding.io/v1/servers/${server_id}" | \
python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data['volumeSizeGb']);
";);

if [ -z "$current_disk_size" ]; then
    exit 1;
else 
    echo $current_disk_size;
    exit 0;
fi