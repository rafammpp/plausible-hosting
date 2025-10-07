# Cleaning nginx and letsencrypt conf before start to avoid errors
cd "$(dirname "$0")";

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

# create backup folders, if they don't exist
mkdir -p backup/clickhouse;
mkdir -p backup/postgres;

# Prevent crons while the server is setting up
mkdir -p crontab/locks;
touch crontab/locks/restore-db.lock;
touch crontab/locks/archive.lock;
touch crontab/locks/setting-up.lock;

if [ ! -f 'plausible-conf.env' ]; then
    echo "-----------------------------------------------";
    echo "ERROR: plausible-conf.env file not found. Please create it and try again.";
    echo "-----------------------------------------------";
    exit 1;
fi

sudo docker compose up -d;

# check compose up exit code
if [ $? -ne 0 ]; then
    echo "-----------------------------------------------";
    echo "ERROR: Docker compose command failed.";
    echo "-----------------------------------------------";
    exit 1;
fi

source plausible-conf.env;

# Generate a secret key with openssl if not set
if [ -z "$SECRET_KEY_BASE" ]; then
    echo "Generating secret key...";
    SECRET_KEY_BASE=$(openssl rand -base64 64 | tr -d '\n' ; echo);
    echo "
SECRET_KEY_BASE=\"$SECRET_KEY_BASE\"
" >> plausible-conf.env;
fi


if [ ! -f crontab/aws/config ] || [ ! -f crontab/aws/credentials ]; then
    # setup aws
    sudo docker compose exec crontab bash -c "aws configure set aws_access_key_id ${R2_ACCESS_KEY_ID}";
    sudo docker compose exec crontab bash -c "aws configure set aws_secret_access_key ${R2_SECRET_ACCESS_KEY}";
    sudo docker compose exec crontab bash -c "aws configure set aws_default_region auto";
    sudo docker compose exec crontab bash -c "aws configure set output json";

    # test aws cli
    echo "-----------------------------------------------";
    echo "Listing bucket for testing aws configuration...";
    sudo docker compose exec crontab bash -c "aws s3 ls s3://$R2_BUCKET/ --endpoint-url $R2_ENDPOINT --region auto";

    # try to upload a test file to the bucket and check if it's there. If not, exit.
    echo "-----------------------------------------------";
    echo "Testing backup upload...";
    sudo docker compose exec crontab bash -c "echo 'test' > /backup/test.txt";
    sudo docker compose exec crontab bash -c "aws s3 cp /backup/test.txt s3://$R2_BUCKET/ --endpoint-url $R2_ENDPOINT --region auto";
    sudo docker compose exec crontab bash -c "rm /backup/test.txt";
    sudo docker compose exec crontab bash -c "aws s3 cp s3://$R2_BUCKET/test.txt /backup/test.txt --endpoint-url $R2_ENDPOINT --region auto";
    # check if the file is there
    if [ ! -f 'backup/test.txt' ]; then
        echo "-----------------------------------------------";
        echo "ERROR: Read/Write test failed. Set valid values for R2_BUCKET, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY R2_ENDPOINT vars in plausible-conf.env and try again.";
        echo "You can generate access_key_id and access_key_secret following this guide https://developers.cloudflare.com/r2/api/s3/tokens/";
        echo "Ensure the bucket exists and the credentials have read/write access to it.";
        echo "-----------------------------------------------";
        rm -f backup/test.txt;
        sudo docker compose exec crontab bash -c "aws s3 rm s3://$R2_BUCKET/test.txt --endpoint-url $R2_ENDPOINT --region auto";
        sudo docker compose down;
        exit 1;
    fi
    rm -f backup/test.txt;
    sudo docker compose exec crontab bash -c "aws s3 rm s3://$R2_BUCKET/test.txt --endpoint-url $R2_ENDPOINT --region auto";

    echo "All good!";
    echo "-----------------------------------------------";
else 
    echo "AWS CLI already configured.";
fi

echo 'Reloading services...';
sudo docker compose down && sudo docker compose up -d;
echo 'Done!';
echo '-----------------------------------------------';
echo "To restore a backup, run the following command:";
echo "sudo docker compose exec crontab /scripts/restore-db.sh";

# Remove locks to allow restoring and archiving
rm crontab/locks/restore-db.lock;
rm crontab/locks/archive.lock;
rm crontab/locks/setting-up.lock;