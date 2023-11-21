# Cleaning nginx and letsencrypt conf before start to avoid errors
rm -rf nginx-reverse-proxy;
rm -rf crontab/letsencrypt;

docker compose up -d;
if [ ! -f 'plausible-conf.env' ]; then
    echo "-----------------------------------------------";
    echo "ERROR: plausible-conf.env file not found. Please create it and try again.";
    echo "-----------------------------------------------";
    exit 1;
fi
source plausible-conf.env;

# setup aws
docker compose exec crontab bash -c "aws configure set aws_access_key_id ${R2_ACCESS_KEY_ID}";
docker compose exec crontab bash -c "aws configure set aws_secret_access_key ${R2_SECRET_ACCESS_KEY}";
docker compose exec crontab bash -c "aws configure set aws_default_region auto";
docker compose exec crontab bash -c "aws configure set output json";

# test aws cli
echo "-----------------------------------------------";
echo "Listing bucket for testing aws configuration...";
docker compose exec crontab bash -c "aws s3 ls s3://$R2_BUCKET/ --endpoint-url $R2_ENDPOINT";

# try to upload a test file to the bucket and check if it's there. If not, exit.
echo "-----------------------------------------------";
echo "Testing backup upload...";
docker compose exec crontab bash -c "echo 'test' > /backup/test.txt";
docker compose exec crontab bash -c "aws s3 cp /backup/test.txt s3://$R2_BUCKET/ --endpoint-url $R2_ENDPOINT";
docker compose exec crontab bash -c "rm /backup/test.txt";
docker compose exec crontab bash -c "aws s3 cp s3://$R2_BUCKET/test.txt /backup/test.txt --endpoint-url $R2_ENDPOINT";
# check if the file is there
if [ ! -f 'backup/test.txt' ]; then
    echo "-----------------------------------------------";
    echo "ERROR: Read/Write test failed. Set valid values for R2_BUCKET, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY R2_ENDPOINT vars in plausible-conf.env and try again.";
    echo "You can generate access_key_id and access_key_secret following this guide https://developers.cloudflare.com/r2/api/s3/tokens/";
    echo "Ensure the bucket exists and the credentials have read/write access to it.";
    echo "-----------------------------------------------";
    rm backup/test.txt;
    docker compose exec crontab bash -c "aws s3 rm s3://$R2_BUCKET/test.txt --endpoint-url $R2_ENDPOINT";
    exit 1;
fi
rm backup/test.txt;
docker compose exec crontab bash -c "aws s3 rm s3://$R2_BUCKET/test.txt --endpoint-url $R2_ENDPOINT";

echo "All good!";
echo "-----------------------------------------------";

echo "Waiting for nginx folder to be created";
# wait until folder nginx-reverse-proxy is created
while [ ! -d "nginx-reverse-proxy" ]; do
    sleep 1;
done

# Check if DOMAINS var exists
if [ -n "$DOMAINS" ]; then
    domains=($DOMAINS);
    echo "Using domains from plausible-conf.env file: ${domains[@]}";
else
    echo "Type any domains you want to add to the plausible server, separated by a space";
    read -a domains;
fi

echo "# Dummy config for certbot
events {
    worker_connections 1024;
}

http {
    server {
        server_name ${domains[@]};
        
        listen 80;
        listen [::]:80;

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
    }
}" > nginx-reverse-proxy/nginx.conf;
docker compose down nginx && docker compose up -d nginx crontab;

domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

echo '-----------------------------------------------';
echo 'Now generating certificates for the domains you added.';
echo '-----------------------------------------------';
docker compose exec crontab bash -c "certbot certonly --webroot -w /var/www/certbot \
    --email $LETS_ENCRYPT_EMAIL \
    $domain_args \
    --non-interactive \
    --cert-name plausible \
    --agree-tos \
    --force-renewal";

echo 'Installing certificates...';
echo '-----------------------------------------------';


# Watch out for $, we need the value of var domains but not $proxy_add_x_forwarded_for, so we use a mix of ' and " to avoid it
echo "# Plausible reverse proxy
events {
    worker_connections 1024;
}

http {
    server {
        server_name ${domains[@]};"'
        
        listen 80;
        listen [::]:80;

        location / {
            proxy_pass http://plausible:8000;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
    }'"
    
    server {
        server_name ${domains[@]};"'

        listen 443 ssl;
        listen [::]:443 ssl;

        ssl_certificate /etc/letsencrypt/live/plausible/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/plausible/privkey.pem;

        location / {
            proxy_pass http://plausible:8000;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
}' > nginx-reverse-proxy/nginx.conf;

echo 'Reloading services...';
docker compose down && docker compose up -d;
echo 'Done!';
