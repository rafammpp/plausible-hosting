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

echo "type any domains you want to add to the plausible server, separated by a space";
read -a domains;
echo '# Plausible reverse proxy
events {
    worker_connections 1024;
}

http {
' > nginx-reverse-proxy/nginx.conf;
for domain in "${domains[@]}"; do
    echo "
    server {
        server_name ${domain};" '
        
        listen 80;
        listen [::]:80;

        location / {
            proxy_pass http://127.0.0.1:8000;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
    }' >> nginx-reverse-proxy/nginx.conf;
done
echo '}' >> nginx-reverse-proxy/nginx.conf;
echo '-----------------------------------------------';
echo 'Now generating certificates for the domains you added. You will be prompted to enter your email address and accept the terms of service.';
echo '-----------------------------------------------';
docker compose exec crontab bash -c 'certbot --nginx';
echo '-----------------------------------------------';
echo 'Reloading services...';
docker compose down && docker compose up -d;
echo 'Done!';