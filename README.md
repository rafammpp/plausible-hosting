# Plausible Analytics docker install
Based on https://github.com/plausible/hosting

This repository allows you to get up and running with [Plausible Analytics](https://github.com/plausible/analytics). It configures a reverse proxy with SSL using Let's Encrypt and sets up a crontab service for automatic backups to Cloudflare R2.

## First install
If you are not using Ubuntu, install docker engine: https://docs.docker.com/engine/install/. Otherwise, the script will do it for you.

Clone this repository to the server and navigate to the directory.

```bash
git clone https://github.com/opusdeits/plausible-hosting.git;
cd plausible-hosting;
```

Create plausible-conf.env at the root of this project, add these vars and set your actual values after the equal sign, no quotes or spaces. Check this if you have any doubts https://plausible.io/docs/self-hosting-configuration about any specific configuration.
SERVER_NAME var values are used to name dirs inside the bucket where backups will be uploaded and downloaded.
For the geolocation db, follow this link and create a license key https://www.maxmind.com/en/accounts/current/license-key, then paste it at `MAXMIND_LICENSE_KEY`. For R2, follow this link https://developers.cloudflare.com/r2/api/s3/tokens/

An important var is `FOLLOWER`. If it is set to true, this will make this server never backup the databases and restore from the configured `RESTORE_FROM_SERVER_NAME` bucket folder. This is useful if you have two servers, one for receiving pageview events and another for making queries to the data.

Check the configuration examples at the end of this file for more details.

```bash
# plausible-conf.env

# Plausible settings 
BASE_URL=
MAXMIND_LICENSE_KEY=
MAXMIND_EDITION=GeoLite2-City
DISABLE_REGISTRATION=invite_only
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
MAILER_EMAIL=
SMTP_HOST_ADDR=
SMTP_HOST_PORT=
SMTP_USER_NAME=
SMTP_USER_PWD=
SMTP_HOST_SSL_ENABLED=true
SMTP_RETRIES=2

# Let's Encrypt settings
LETS_ENCRYPT_EMAIL=
DOMAINS=

# R2 backup and restore settings
DISABLE_CRON_SCRIPTS= # to disable all cron automated scripts
BACKUP_TO_SERVER_NAME=
RESTORE_FROM_SERVER_NAME=
R2_BUCKET=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_ENDPOINT=

# clouding.io settings
FOLLOWER=false # if set to true, this server will never backup. It will only do a restore from the configured SERVER_NAME bucket folder
CLOUDING_APIKEY=
FOLLOWER_TO_WAKEUP=  # the ip of the follower server
AUTO_RESIZE_DISK=false # if set to true, the server will resize the disk before restoring if needed.
```

`SECRET_KEY_BASE` Will be generated and put here later by the script itself. But you can place your own if you want.

Now that you have the env file it's time to run `./first-start.sh` the script will configure everything for you, providing all config vars are correctly setup in plausible-conf.env
You only need to run this the first time.

## Use S3 instead of R2
R2 is a Cloudflare service that is compatible with S3. The main difference is that R2 is cheaper and don't has egress fees. See more at [R2 vs S3](https://www.cloudflare.com/es-es/pg-cloudflare-r2-vs-aws-s3/).

R2 api is compatible with S3, we even use aws-cli to connect to it. So, of course, you can use S3 instead. Just set the R2_ENDPOINT to the S3 endpoint and the R2_BUCKET to the S3 bucket name and the access and secret keys from S3.

## Configuration examples
You always need the plausible part of settings but all the other settings are optional. In the following examples we will skip the plausible settings and only show the optional ones.

There are basically three types of configurations: 
1. **Minimal**. A single server with plausible, no automated scripts.
2. **Single server** with plausible and cron scripts for backups and restores and let's encrypt; 
3. **Two servers**, one for receiving pageview events and another for making queries to the data. Named as leader and follower. At least the follower server needs to be on [clouding.io](clouding.io), because it needs to be woken up by the leader server. Nore on this later.

### How to choose between the three
For local testing, the minimal configuration is enough. For a production server, with less than five million pageviews per month the single server configuration is ok. For more than that and if you don't want to expend 300$ per month, you should use the two servers configuration.

### Minimal configuration, a single server with no backups or restore and no Let's Encrypt SSL
You can skip the first-start.sh script. The only thing you need is a `SECRET_KEY_BASE` and the other plausible vars, and a nginx.conf file. There is a configuration example here: `nginx-reverse-proxy/nginx.conf.example`. You can rename it to `nginx.conf`, replacing `localhost` with your domain and it will work.

```bash
# plausible settings
...

DISABLE_CRON_SCRIPTS=true
FOLLOWER=false
```

### Single server with automatic backups to R2 and Let's Encrypt SSL
If you don't need SSL or you already have it configured, you can disable it on the first-start.sh script. It will ask you if you want to do so.

The crontab table used is in this repository, at `crontab/table/cron`. 

```bash
# plausible settings
...

LETS_ENCRYPT_EMAIL=your_email@email.com
DOMAINS="your_domain.com your_other_domain.com"
FOLLOWER=false
BACKUP_TO_SERVER_NAME=plausible-backups
RESTORE_FROM_SERVER_NAME=plausible-backups
R2_BUCKET=your_bucket_name
R2_ACCESS_KEY_ID=your_access_key
R2_SECRET_ACCESS_KEY=your_secret_key
R2_ENDPOINT=your_endpoint
```

### Two servers, leader and follower
This is my actual use case.

We have two roles, leader and follower. The leader receives the pageview events and it's always active. The follower is most of the time asleep and is the one responsible of making queries for stadistical reports. The leader will never automatically restore the databases, it will only make backups. Then, the follower will restore from the leader's backups to be always up to date.

#### Leader
The leader is configured as a single server plus some one more var, `FOLLOWER_TO_WAKEUP`. This is the ip of the follower server. The leader will wake up the follower after a backup for the follower to restore from the leader's backups.

```bash
# plausible settings
...
LETS_ENCRYPT_EMAIL=your_email@email.com
DOMAINS="leader.your_domain.com leader.your_other_domain.com"

BACKUP_TO_SERVER_NAME=plausible-leader
RESTORE_FROM_SERVER_NAME=plausible-leader # this is needed for manual restores
R2_BUCKET=your_bucket_name
R2_ACCESS_KEY_ID=your_access_key
R2_SECRET_ACCESS_KEY=your_secret_key
R2_ENDPOINT=your_endpoint

FOLLOWER=false
CLOUDING_APIKEY=your_clouding_api_key
FOLLOWER_TO_WAKEUP=  # the ip of the follower server
```

#### Follower
The follower will try to restore from the leader's backups on wake up if needed. It will also resize the disk before restoring if needed.

```bash
# plausible settings
...
LETS_ENCRYPT_EMAIL=your_email@email.com
DOMAINS="follower.your_domain.com follower.your_other_domain.com"

BACKUP_TO_SERVER_NAME=plausible-follower # this is needed for logs and manual backups
RESTORE_FROM_SERVER_NAME=plausible-leader
R2_BUCKET=your_bucket_name
R2_ACCESS_KEY_ID=your_access_key
R2_SECRET_ACCESS_KEY=your_secret_key
R2_ENDPOINT=your_endpoint

FOLLOWER=true
CLOUDING_APIKEY=your_clouding_api_key
AUTO_RESIZE_DISK=true # if set to true, the server will resize the disk before restoring if needed.
```

### How to wake up the follower
You have three options: use the clouding.io admin panel, use the [clouding api](https://api.clouding.io/docs) or, if you use django, check out my other repository [clouding-wake-up](https://github.com/rafammpp/django-clouding-unarchive). It's a simple django app that wakes up a server when you press a button. It's useful if you have a django website and want to wake up the follower from it's admin.

### About Clouding.io
Clouding.io is a simple cloud provider that allows you to choose the amount of CPU, RAM and disk space you need. You can resize it later, has persistent data storage and can be archived to save a lot of money. It's a good option for a follower server. It's also a good option for a leader server, but you will need to pay for the whole month, so a VPS is a cheaper option most of the time.

You can use another cloud provider, but you will need to fork this repository and change the wake up call at `crontab/scripts/cron-backup.sh` and the sleep call at `crontab/scripts/cron-archive.sh` to use the other provider's api.

## Useful commands
### Make a manual backup of databases and upload it to R2
This requires you to have configured R2 vars in `plausible-conf.env`. Optionally, you can pass the R2 folder name as the first positinal argument, if not, it will use the current `BACKUP_TO_SERVER_NAME` value.

From this folder run this:

```bash
docker compose exec crontab bash -c "/scripts/backup-db.sh"
```
or
```bash
docker compose exec crontab bash -c "/scripts/backup-db.sh your_folder_name"
```

### Restore last backup from R2
***WARNING!!!! This will destroy all current data and cannot be undone.***

This will download the last backup of both databases, **drop the existing tables** and then restore. Optionally, you can pass the R2 folder name as the first positinal argument, if not, it will use the current `RESTORE_FROM_SERVER_NAME` value.

```bash
docker compose exec crontab bash -c "/scripts/restore-db.sh"
```
or
```bash
docker compose exec crontab bash -c "/scripts/restore-db.sh your_folder_name"
```

### Increase the API keys request limit
API keys have a default limit of 600 requests per hour. If you want to change it to the maximum value, do the following:

```bash
docker compose exec plausible_db psql -U postgres -d plausible_db -c 'UPDATE api_keys SET hourly_request_limit = 2147483647'
```

That will set the limit to the highest possible value.
