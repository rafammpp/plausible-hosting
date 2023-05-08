# Plausible Analytics docker install
Based on https://github.com/plausible/hosting

This repository allows you to get up and running with [Plausible Analytics](https://github.com/plausible/analytics).
In addition, it has several scripts to make backups of both databases to Amazon S3.

## First install
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


Create plausible-conf.env at the root of this project, add this vars and set your actual values after the equal sig, no quotes or spaces. Paste the generated key from the previous step at `SECRECT_KEY_BASE` Check this if you have any doubts https://plausible.io/docs/self-hosting-configuration about any specific configuration.
For the geolocalization db follow this link and create a license key https://www.maxmind.com/en/accounts/current/license-key, then paste at `MAXMIND_LICENSE_KEY`.
```
BASE_URL=
SECRET_KEY_BASE=
GEONAMES_SOURCE_FILE=/path/to/geonames.csv
MAXMIND_LICENSE_KEY=
MAXMIND_EDITION=GeoLite2-City
DISABLE_REGISTRATION=invite_only
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
CRON_ENABLED=true
MAILER_EMAIL=example@gmail.com
SMTP_HOST_ADDR=smtp.gmail.com
SMTP_HOST_PORT=465
SMTP_USER_NAME=example@gmail.com
SMTP_USER_PWD=
SMTP_HOST_SSL_ENABLED=true
SMTP_RETRIES=2
S3_BUCKET=bucket-name
```

## Backup databases and upload to S3
This requires you to have installed and configured aws cli and have set S3_BUCKET var in plausible-conf.env
From this folder run this:
```bash
./backup-db.sh
```
This will stop temporarily plausible, make backups, restart plausible and then upload to S3.

You can automate this with [crontab](https://crontab.guru/) with something like this:
```bash
0 4 * * * /absolute/path/to/backup-db.sh
```
That will make a backup everyday at 4:00 am

## Restore last backup from S3
***WARNING!!!! This will destroy all current data and can not be undone.***

This will download the last backup of both databases, **drop the actual tables**, and then restore.
```bash
./restore-db.sh
```