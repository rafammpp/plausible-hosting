
last_query=$(tail -n 100 logs/nginx/access.log | grep /api/stats/ | grep = | grep 200 | tail -n 1 |  grep --only-matching -E "\[.+\]" | sed 's/[][]//g' | sed 's/\//-/g' | sed 's/:/ /' | sed 's/ +0000//');

# calculate the number of hours since the last query
time_diff=$(date -d "$last_query" +%s) $(date +%s) | awk '{print ($2 - $1) / 3600}'

# check if the difference is greater than 1 hour
if [ $time_diff -gt 1 ]; then
    echo "The last query was more than 1 hour ago"
else
    echo "The last query was less than 1 hour ago"
fi

