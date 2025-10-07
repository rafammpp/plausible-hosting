# Plausible Analytics Docker Install
Based on https://github.com/plausible/hosting

This repository allows you to get up and running with [Plausible Analytics](https://github.com/plausible/analytics). It sets up a crontab service for automatic backups to Cloudflare R2.

## First Install
If you are not using Ubuntu, install Docker Engine: https://docs.docker.com/engine/install/. Otherwise, the script will do it for you.

Clone this repository to the server and navigate to the directory.

```bash
git clone --recurse-submodules https://github.com/opusdeits/plausible-hosting.git;
cd plausible-hosting;
```

We get the Docker Compose file from Plausible's repository Community Edition as a submodule and override it with our own compose.override.yml file.

Create .env at the root of this project, add these variables and set your actual values after the equal sign, with no quotes or spaces. Check this if you have any doubts https://plausible.io/docs/self-hosting-configuration about any specific configuration.
SERVER_NAME variable values are used to name directories inside the bucket where backups will be uploaded and downloaded.
For the geolocation database, follow this link and create a license key https://www.maxmind.com/en/accounts/current/license-key, then paste it at `MAXMIND_LICENSE_KEY`. For R2, follow this link https://developers.cloudflare.com/r2/api/s3/tokens/

An important variable is `FOLLOWER`. If it is set to true, this will make this server never back up the databases and restore from the configured `RESTORE_FROM_SERVER_NAME` bucket folder. This is useful if you have two servers: one for receiving pageview events and another for making queries to the data.

### Note About SSL
Plausible now comes with Let's Encrypt support out of the box. You have to set the `BASE_URL` variable to your domain name with https:// at the beginning and set the `HTTPS_PORT` variable to 443. The script will automatically request a certificate for you if you have set the correct domain name and the domain points to this server's IP address. You don't need to do anything else. If you want to disable this, just set the `HTTP_PORT` variable to 80 or whatever port you want to use and don't set the `HTTPS_PORT` variable.

Check the configuration examples at the end of this file for more details.

```bash
# .env

# Plausible settings 
BASE_URL=
HTTP_PORT=80 # or whatever port you want to use
HTTPS_PORT=443 # If this is set, the script will try to get a Let's Encrypt certificate for the BASE_URL domain for you
MAXMIND_EDITION=GeoLite2-City
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
MAILER_EMAIL=
SMTP_HOST_ADDR=
SMTP_HOST_PORT=
SMTP_USER_NAME=
SMTP_USER_PWD=
SMTP_HOST_SSL_ENABLED=true
SMTP_RETRIES=2

# R2 backup and restore settings
DISABLE_CRON_SCRIPTS= # to disable all automated cron scripts
BACKUP_TO_SERVER_NAME=
RESTORE_FROM_SERVER_NAME=
R2_BUCKET=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_ENDPOINT=

# clouding.io settings
FOLLOWER=false # if set to true, this server will never back up. It will only restore from the configured SERVER_NAME bucket folder
CLOUDING_APIKEY=
FOLLOWER_TO_WAKEUP=  # the IP of the follower server
AUTO_RESIZE_DISK=false # if set to true, the server will resize the disk before restoring if needed.
```

`SECRET_KEY_BASE` will be generated and placed here later by the script itself. But you can place your own if you want.

Now that you have the env file, it's time to run `./first-start.sh`. The script will configure everything for you, provided all configuration variables are correctly set up in .env.
You only need to run this the first time.

## Use S3 Instead of R2
R2 is a Cloudflare service that is compatible with S3. The main difference is that R2 is cheaper and doesn't have egress fees. See more at [R2 vs S3](https://www.cloudflare.com/es-es/pg-cloudflare-r2-vs-aws-s3/).

The R2 API is compatible with S3; we even use AWS CLI to connect to it. So, of course, you can use S3 instead. Just set the R2_ENDPOINT to the S3 endpoint and the R2_BUCKET to the S3 bucket name and the access and secret keys from S3.

## Configuration Examples
You always need the Plausible part of the settings, but all the other settings are optional. In the following examples, we will skip the Plausible settings and only show the optional ones.

There are basically three types of configurations: 
1. **Minimal**. A single server with Plausible, no automated scripts.
2. **Single server** with Plausible and cron scripts for backups and restores and Let's Encrypt; 
3. **Two servers**, one for receiving pageview events and another for making queries to the data. Named as leader and follower. At least the follower server needs to be on [clouding.io](clouding.io), because it needs to be woken up by the leader server. More on this later.

### How to Choose Between the Three
For local testing, the minimal configuration is enough. For a production server with less than five million pageviews per month, the single server configuration is OK. For more than that, and if you don't want to spend $300 per month, you should use the two-server configuration.

### Minimal Configuration: A Single Server with No Backups or Restore and No Let's Encrypt SSL
You can skip the first-start.sh script. The only thing you need is a `SECRET_KEY_BASE` and the other Plausible variables.

```bash
# plausible settings
...

DISABLE_CRON_SCRIPTS=true
FOLLOWER=false
```

### Single Server with Automatic Backups to R2
The crontab table used is in this repository, at `crontab/table/cron`. 

```bash
# plausible settings
...
FOLLOWER=false
BACKUP_TO_SERVER_NAME=plausible-backups
RESTORE_FROM_SERVER_NAME=plausible-backups
R2_BUCKET=your_bucket_name
R2_ACCESS_KEY_ID=your_access_key
R2_SECRET_ACCESS_KEY=your_secret_key
R2_ENDPOINT=your_endpoint
```

### Two Servers: Leader and Follower
This is my actual use case.

We have two roles: leader and follower. The leader receives the pageview events and is always active. The follower is asleep most of the time and is responsible for making queries for statistical reports. The leader will never automatically restore the databases; it will only make backups. Then, the follower will restore from the leader's backups to stay up to date.

#### Leader
The leader is configured as a single server plus one more variable, `FOLLOWER_TO_WAKEUP`. This is the IP of the follower server. The leader will wake up the follower after a backup for the follower to restore from the leader's backups.

```bash
# plausible settings
...
BACKUP_TO_SERVER_NAME=plausible-leader
RESTORE_FROM_SERVER_NAME=plausible-leader # this is needed for manual restores
R2_BUCKET=your_bucket_name
R2_ACCESS_KEY_ID=your_access_key
R2_SECRET_ACCESS_KEY=your_secret_key
R2_ENDPOINT=your_endpoint

FOLLOWER=false
CLOUDING_APIKEY=your_clouding_api_key
FOLLOWER_TO_WAKEUP=  # the IP of the follower server
```

#### Follower
The follower will try to restore from the leader's backups on wake-up if needed. It will also resize the disk before restoring if needed.

```bash
# plausible settings
...
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

### How to Wake Up the Follower
You have three options: use the clouding.io admin panel, use the [clouding API](https://api.clouding.io/docs), or, if you use Django, check out my other repository [clouding-wake-up](https://github.com/rafammpp/django-clouding-unarchive). It's a simple Django app that wakes up a server when you press a button. It's useful if you have a Django website and want to wake up the follower from its admin.

### About Clouding.io
Clouding.io is a simple cloud provider that allows you to choose the amount of CPU, RAM, and disk space you need. You can resize it later, has persistent data storage, and can be archived to save a lot of money. It's a good option for a follower server. It's also a good option for a leader server, but you will need to pay for the whole month, so a VPS is usually a cheaper option.

You can use another cloud provider, but you will need to fork this repository and change the wake-up call at `crontab/scripts/cron-backup.sh` and the sleep call at `crontab/scripts/cron-archive.sh` to use the other provider's API.

## Useful Commands
### Make a Manual Backup of Databases and Upload It to R2
This requires you to have configured R2 variables in `plausible-conf.env`. Optionally, you can pass the R2 folder name as the first positional argument; if not, it will use the current `BACKUP_TO_SERVER_NAME` value.

From this folder, run this:

```bash
docker compose exec crontab bash -c "/scripts/backup-db.sh"
```
or
```bash
docker compose exec crontab bash -c "/scripts/backup-db.sh your_folder_name"
```

### Restore Last Backup from R2
***WARNING!!!! This will destroy all current data and cannot be undone.***

This will download the last backup of both databases, **drop the existing tables**, and then restore. Optionally, you can pass the R2 folder name as the first positional argument; if not, it will use the current `RESTORE_FROM_SERVER_NAME` value.

```bash
docker compose exec crontab bash -c "/scripts/restore-db.sh"
```
or
```bash
docker compose exec crontab bash -c "/scripts/restore-db.sh your_folder_name"
```