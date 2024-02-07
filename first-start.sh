# Cleaning nginx and letsencrypt conf before start to avoid errors
rm -rf nginx-reverse-proxy;
rm -rf crontab/letsencrypt;

echo "-----------------------------------------------";
echo "Welcome to the Plausible Analytics server setup!";
echo "-----------------------------------------------";
echo "This script will guide you through the setup process.";
echo "Make sure you have setup domain DNS records to point to this server and fill the variables in plausible-conf.env before continuing. You can find more info about this in the README file.";
echo "Press any key when you are ready to continue or CTRL+C to exit.";
echo "-----------------------------------------------";
read -n 1 -s;

# Check if docker exists
if ! command -v docker &> /dev/null
then
    echo "Installing Docker engine...";
    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

docker compose up -d;
if [ ! -f 'plausible-conf.env' ]; then
    echo "-----------------------------------------------";
    echo "ERROR: plausible-conf.env file not found. Please create it and try again.";
    echo "-----------------------------------------------";
    docker compose down;
    exit 1;
fi
source plausible-conf.env;

# Generate a secret key with openssl if not set
if [ -z "$SECRET_KEY_BASE" ]; then
    echo "Generating secret key...";
    SECRET_KEY_BASE=$(openssl rand -base64 64 | tr -d '\n' ; echo);
    echo "SECRET_KEY_BASE=$SECRET_KEY_BASE" >> plausible-conf.env;
fi

# setup aws
docker compose exec crontab bash -c "aws configure set aws_access_key_id ${R2_ACCESS_KEY_ID}";
docker compose exec crontab bash -c "aws configure set aws_secret_access_key ${R2_SECRET_ACCESS_KEY}";
docker compose exec crontab bash -c "aws configure set aws_default_region auto";
docker compose exec crontab bash -c "aws configure set output json";

# test aws cli
echo "-----------------------------------------------";
echo "Listing bucket for testing aws configuration...";
docker compose exec crontab bash -c "aws s3 ls s3://$R2_BUCKET/ --endpoint-url $R2_ENDPOINT --region auto";

# try to upload a test file to the bucket and check if it's there. If not, exit.
echo "-----------------------------------------------";
echo "Testing backup upload...";
docker compose exec crontab bash -c "echo 'test' > /backup/test.txt";
docker compose exec crontab bash -c "aws s3 cp /backup/test.txt s3://$R2_BUCKET/ --endpoint-url $R2_ENDPOINT --region auto";
docker compose exec crontab bash -c "rm /backup/test.txt";
docker compose exec crontab bash -c "aws s3 cp s3://$R2_BUCKET/test.txt /backup/test.txt --endpoint-url $R2_ENDPOINT --region auto";
# check if the file is there
if [ ! -f 'backup/test.txt' ]; then
    echo "-----------------------------------------------";
    echo "ERROR: Read/Write test failed. Set valid values for R2_BUCKET, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY R2_ENDPOINT vars in plausible-conf.env and try again.";
    echo "You can generate access_key_id and access_key_secret following this guide https://developers.cloudflare.com/r2/api/s3/tokens/";
    echo "Ensure the bucket exists and the credentials have read/write access to it.";
    echo "-----------------------------------------------";
    rm backup/test.txt;
    docker compose exec crontab bash -c "aws s3 rm s3://$R2_BUCKET/test.txt --endpoint-url $R2_ENDPOINT --region auto";
    docker compose down;
    exit 1;
fi
rm backup/test.txt;
docker compose exec crontab bash -c "aws s3 rm s3://$R2_BUCKET/test.txt --endpoint-url $R2_ENDPOINT --region auto";

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
echo "Do you want to use Let's Encrypt to generate SSL certificates for your domains? (y/n)";
read -n 1 -s lets_encrypt;
if [ "$lets_encrypt" = "y" ]; then
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

            location /robots.txt {
                add_header Content-Type text/plain;
                return 200 "User-agent: *\nDisallow: /\n";
            }

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

            location /robots.txt {
                add_header Content-Type text/plain;
                return 200 "User-agent: *\nDisallow: /\n";
            }

            location / {
                proxy_pass http://plausible:8000;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            }
        }
    }' > nginx-reverse-proxy/nginx.conf;
else 
    echo '-----------------------------------------------';
    echo "Skipping Let\'s Encrypt setup.";
    echo '-----------------------------------------------';
    echo "# Plausible reverse proxy, No SSL
    events {
        worker_connections 1024;
    }

    http {
        server {
            server_name ${domains[@]};"'
            
            listen 80;
            listen [::]:80;

            location /robots.txt {
                add_header Content-Type text/plain;
                return 200 "User-agent: *\nDisallow: /\n";
            }

            location / {
                proxy_pass http://plausible:8000;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            }
        }
    }' > nginx-reverse-proxy/nginx.conf;
fi


echo 'Reloading services...';
docker compose down && docker compose up -d;
echo 'Done!';
echo '-----------------------------------------------';
echo "To restore a backup, run the following command:";
echo "docker compose exec crontab /restore-db.sh";
