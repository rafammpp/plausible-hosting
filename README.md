# Plausible Analytics docker install
Based on https://github.com/plausible/hosting

This repository allows you to get up and running with [Plausible Analytics](https://github.com/plausible/analytics). It configures a reverse proxy with SSL using Let's Encrypt and sets up a crontab service for automatic backups to Cloudflare R2.
In addition, it includes several scripts to restore backups of both databases from Cloudflare R2.

## First install
Install docker engine: https://docs.docker.com/engine/install/

Clone this repository to the server and navigate to the directory.
```
git clone https://github.com/opusdeits/plausible-hosting.git;
cd plausible-hosting;
```

Create plausible-conf.env at the root of this project, add these vars and set your actual values after the equal sign, no quotes or spaces. Check this if you have any doubts https://plausible.io/docs/self-hosting-configuration about any specific configuration.
`SERVER_NAME` value is used to name a dir inside the bucket where backups will be uploaded. It has to be different from other servers you have.
For the geolocation db, follow this link and create a license key https://www.maxmind.com/en/accounts/current/license-key, then paste it at `MAXMIND_LICENSE_KEY`. For R2, follow this link https://developers.cloudflare.com/r2/api/s3/tokens/

An important var is `FOLLOWER`. If it is set to true, this will make this server never backup and restore from the configured `SERVER_NAME` bucket folder. This is useful if you have two servers, one for receiving pageview events and another for making queries to the data.
```
BASE_URL=
FOLLOWER=false
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

`SECRET_KEY_BASE` Will be generated and put here later by the script itself. But you can place your own if you want.

Now that you have the env file it's time to run `./first-start.sh` the script will configure everything for you, providing all config vars are correctly setup in plausible-conf.env
You only need to run this the first time.

## Manual backup databases and upload to R2
This requires you to have configured R2 vars in plausible-conf.env
From this folder run this:
```bash
docker compose exec crontab bash -c "/backup-db.sh"
```

## Restore last backup from R2
***WARNING!!!! This will destroy all current data and cannot be undone.***

This will download the last backup of both databases, **drop the existing tables** and then restore.
```bash
docker compose exec crontab bash -c "/restore-db.sh"
```
## Increase the API keys request limit
API keys have a default limit of 600 requests per hour. If you want to change it to the maximum value, do the following:
```bash
docker compose exec plausible_db psql -U postgres -d plausible_db -c 'UPDATE api_keys SET hourly_request_limit = 2147483647'
```

That will set the limit to the highest possible value.
