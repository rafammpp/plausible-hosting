# docker compose up -d;
# echo "Setup AWS CLI following this pattern:";
# echo "
# AWS Access Key ID [None]: <access_key_id>
# AWS Secret Access Key [None]: <access_key_secret>
# Default region name [None]: auto
# Default output format [None]: json
# -----------------------------------------------
# Generate access_key_id and access_key_secret following this guide https://developers.cloudflare.com/r2/api/s3/tokens/
# -----------------------------------------------";
# docker compose exec crontab bash -c "aws configure";

echo "type any domains you want to add to the plausible server, separated by a space";
read -a domains;
for domain in "${domains[@]}"; do
    echo "server {
	# replace example.com with your domain name
	server_name ${domain};" '
	
	listen ${NGINX_PORT};
	listen [::]:${NGINX_PORT};

	location / {
		proxy_pass http://127.0.0.1:8000;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
	}
}

' >> nginx-reverse-proxyplausible;
done

