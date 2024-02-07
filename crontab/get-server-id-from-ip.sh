#!/bin/bash
source /run/secrets/plausible-conf;

# get the current server id, based on the first argument that is the public ip
public_ip=$1;

if [ -z "$public_ip" ] || [ -z "$CLOUDING_APIKEY" ]; then
    exit 1;
fi

server_id=$(curl -X GET -H "Content-Type: application/json" -H "X-API-KEY: $CLOUDING_APIKEY" "https://api.clouding.io/v1/servers?page=1&pageSize=2" | \
    python3 -c "
    import sys, json
    data = json.load(sys.stdin)
    for server in data['servers']:
        if server['publicIp'] == '$public_ip':
            print(server['id'])
            break
    ";
);

if [ -z "$server_id" ]; then
    exit 1;
else 
    echo $server_id;
    exit 0;
fi
