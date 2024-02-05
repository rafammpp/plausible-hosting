#!/bin/bash

# This script checks if the last query to the plausible server was more than 1 hour ago
# If it was, it resizes the server to the smallest flavor available


source /run/secrets/plausible-conf;

last_query=$(tail -n 100 logs/nginx/access.log | grep /api/stats/ | grep = | grep 200 | tail -n 1 |  grep -o -E "\[.+\]" | sed 's/[][]//g' | sed 's/\//-/g' | sed 's/:/ /' | sed 's/ +0000//');


# check if the last query is empty
if [ -z "$last_query" ]; then
    time_diff=3601;
else
    # calculate the number of seconds since the last query
    time_diff=$( echo $(date -d "$last_query" +%s) $(date +%s) | awk '{print ($2 - $1)}');
fi

# check if the difference is greater than 1 hour
if [ $time_diff -gt 3600 ]; then
    echo "The last query was more than 1 hour ago"
    # check number of cores
    cores=$(nproc --all);
    if [ $cores -gt 1 ]; then
        echo "Resizing the server to the smallest flavor available...";
        # get the current server id, based on the public ip 
        public_ip=$(curl -s ifconfig.me);
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
            echo "ERROR: Server not found in clouding.io";
            exit 1;
        fi

        # get the smallest flavor available
        flavor=$(curl -X GET -H "Content-Type: application/json" -H "X-API-KEY: $CLOUDING_APIKEY" "https://api.clouding.io/v1/sizes/flavors?page=1&pageSize=2" | \
            python3 -c "
            import sys, json
            data = json.load(sys.stdin)
            for flavor in data['flavors']:
                if flavor['vCores'] == 0.5:
                    print(flavor['id'])
                    break
            ";
        );

        if [ -z "$flavor" ]; then
            echo "ERROR: Flavor not found in clouding.io";
            exit 1;
        fi

        # resize the server
        curl -X POST -H "Content-Type: application/json" -H "X-API-KEY: $CLOUDING_APIKEY" -d "{\"flavorId\": \"$flavor\"}" "https://api.clouding.io/v1/servers/$server_id/resize";
        exit 0;
    else
        echo "The server already has the smallest flavor available";
        exit 0;
    fi
fi

echo "The last query was less than 1 hour ago, resizing the server...";
# check number of cores
cores=$(nproc --all);
if [ $cores -lt 4 ]; then
    echo "Resizing the server to the largest flavor available...";
    # get the current server id, based on the public ip 
    public_ip=$(curl -s ifconfig.me);
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
        echo "ERROR: Server not found in clouding.io";
        exit 1;
    fi

    # get the largest flavor available
    flavor=$(curl -X GET -H "Content-Type: application/json" -H "X-API-KEY: $CLOUDING_APIKEY" "https://api.clouding.io/v1/sizes/flavors?page=1&pageSize=2" | \
        python3 -c "
        import sys, json
        data = json.load(sys.stdin)
        for flavor in data['flavors']:
            if flavor['vCores'] == 32:
                print(flavor['id'])
                break
        ";
    );

    if [ -z "$flavor" ]; then
        echo "ERROR: Flavor not found in clouding.io";
        exit 1;
    fi

    # resize the server
    curl -X POST -H "Content-Type: application/json" -H "X-API-KEY: $CLOUDING_APIKEY" -d "{\"flavorId\": \"$flavor\"}" "https://api.clouding.io/v1/servers/$server_id/resize";
    exit 0;
else
    echo "The server already has the largest flavor available";
    exit 0;
fi
