#!/bin/bash

last_query=$(tail -n 100 /logs/nginx/access.log | grep /api/stats/ | grep = | grep 200 | tail -n 1 |  grep -o -E "\[.+\]" | sed 's/[][]//g' | sed 's/\//-/g' | sed 's/:/ /' | sed 's/ +0000//');


# check if the last query is empty
if [ -z "$last_query" ]; then
    time_diff=3601;
else
    # calculate the number of seconds since the last query
    time_diff=$( echo $(date -d "$last_query" +%s) $(date +%s) | awk '{print ($2 - $1)}');
fi

# check if the difference is greater than 1 hour
if [ $time_diff -gt 3600 ]; then
    echo false;
else
    echo true;
fi
