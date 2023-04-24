export MAXMIND_LICENSE_KEY=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
curl -O https://s3.eu-central-1.wasabisys.com/plausible-application/geonames.csv;
curl -L "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=${MAXMIND_LICENSE_KEY}&suffix=tar.gz" -o geolite2-city.mmdb.gz;
gunzip geolite2-city.mmdb.gz;
