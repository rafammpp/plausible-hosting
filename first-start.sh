docker compose up -d;
echo "Setup AWS CLI following this pattern:";
echo "
AWS Access Key ID [None]: <access_key_id>
AWS Secret Access Key [None]: <access_key_secret>
Default region name [None]: auto
Default output format [None]: json
-----------------------------------------------
Generate access_key_id and access_key_secret following this guide https://developers.cloudflare.com/r2/api/s3/tokens/
-----------------------------------------------";
docker compose exec crontab bash -c "aws configure";
