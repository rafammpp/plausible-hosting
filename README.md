# Plausible Analytics docker install
Based on https://github.com/plausible/hosting

This repository allows you to get up and running [Plausible Analytics](https://github.com/plausible/analytics). It configure a reverse proxy with ssl with let's encrypt and setup a crontab service for automatic backups to Cloudflare R2.
In addition, it has several scripts to restore backups of both databases from Cloudflare R2.

## First install
Install docker engine: https://docs.docker.com/engine/install/

Clone this repo to the server and enter to the directory.
```
git clone https://github.com/opusdeits/plausible-hosting.git;
cd plausible-hosting;
```
Generate a secret key:
```
openssl rand -base64 64 | tr -d '\n' ; echo
```
Copy the generated key, we need it in the next step.


Create plausible-conf.env at the root of this project, add this vars and set your actual values after the equal sig, no quotes or spaces. Paste the generated key from the previous step at `SECRET_KEY_BASE` Check this if you have any doubts https://plausible.io/docs/self-hosting-configuration about any specific configuration.
`SERVER_NAME` value is used to name a dir inside the bucket where the backups will be upload. It has to be different from others servers you have.
For the geolocalization db follow this link and create a license key https://www.maxmind.com/en/accounts/current/license-key, then paste at `MAXMIND_LICENSE_KEY`. For R2 follow this https://developers.cloudflare.com/r2/api/s3/tokens/
```
BASE_URL=
SECRET_KEY_BASE=
MAXMIND_LICENSE_KEY=
MAXMIND_EDITION=GeoLite2-City
DISABLE_REGISTRATION=invite_only
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
CRON_ENABLED=true
MAILER_EMAIL=
SMTP_HOST_ADDR=
SMTP_HOST_PORT=
SMTP_USER_NAME=
SMTP_USER_PWD=
SMTP_HOST_SSL_ENABLED=true
SMTP_RETRIES=2

export PGUSER=postgres
export PGPASSWORD=postgres
SERVER_NAME= # for identifying the server in backups
R2_BUCKET=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_ENDPOINT=
```

Now that you have the env file it's time to run `./first-start.sh` the script will config everything for you, providing all config vars are correctly setup in plausible-conf.env
You only need to run this the first time.

## Manual backup databases and upload to R2
This requires you to have installed and configured aws cli and have set S3_BUCKET var in plausible-conf.env
From this folder run this:
```bash
docker compose exec crontab bash -c "/backup-db.sh"
```

## Restore last backup from S3
***WARNING!!!! This will destroy all current data and can not be undone.***

This will download the last backup of both databases, **drop the actual tables**, and then restore.
```bash
docker compose exec crontab bash -c "/restore-db.sh"
```
## Increase the api keys request limit
Api keys has a default limit of 600 request per hour. If you wanna change it to the maximum value do this:
```bash
docker compose exec plausible_db psql -U postgres -d plausible_db -c 'UPDATE api_keys SET hourly_request_limit = 2147483647'
```

That will set the limit to the highest posible value.
