#!/bin/bash

# check if exists a archive lock file
if [ -f /locks/archive.lock ]; then
    echo true;
    exit 0;
fi
# add /api/v2/query to take into account new plausible api
# get the last query time from plausible log excluding /current-visitors
last_query=$(cat /logs/plausible.log | grep -v /current-visitors | grep -E "/api/stats/|/api/v2/query" | grep = | grep 200 | tail -n 1 | grep -oE '^[^ ]* ');


# check if the last query is empty
if [ -z "$last_query" ]; then
    time_diff=3001;
else
    # calculate the number of seconds since the last query
    time_diff=$( echo $(date -d "$last_query" +%s) $(date +%s) | awk '{print ($2 - $1)}');
fi

# check if the difference is greater than 50 minutes
if [ $time_diff -gt 3000 ]; then
    echo false;
else
    echo true;
fi
