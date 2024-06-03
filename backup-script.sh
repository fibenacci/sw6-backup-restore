#!/bin/bash

SHOP_DIR="$PWD/shop"

usage() {
    echo "Usage: $0 [-s shop_dir] [-u username] [-h host] [-d destination_path]"
    echo "Options:"
    echo "  -s    Specify the shop directory (default: shop)"
    echo "  -u    Specify the username for SCP"
    echo "  -h    Specify the host for SCP"
    echo "  -d    Specify the destination path on the remote server"
    exit 1
}

download_shopware_cli() {
    echo "Downloading and configuring Shopware CLI Tools..."
    cd ~/../../web/
    mkdir -p shopware_cli && cd shopware_cli
    wget https://github.com/FriendsOfShopware/shopware-cli/releases/download/0.4.19/shopware-cli_Linux_x86_64.tar.gz
    tar xfvz shopware-cli_Linux_x86_64.tar.gz
    rm shopware-cli_Linux_x86_64.tar.gz
    ./shopware-cli project config init
}

urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

create_mysql_backup() {
    echo "Creating MySQL backup using Shopware CLI Tools..."

    ENV_FILE="$SHOP_DIR/.env.local"
    
    if [ ! -f "$ENV_FILE" ]; then
        echo ".env file not found in $SHOP_DIR. Please enter the required information:"
        read -p "Database name: " DB_NAME
        read -p "Database host: " DB_HOST
        read -p "Database port: " DB_PORT
        read -p "Database username: " DB_USER
        read -sp "Database password: " DB_PASS
        echo
    else
        echo "Reading database credentials from DATABASE_URL in .env file..."
        export $(grep -v '^#' "$ENV_FILE" | xargs)
        
        if [ -z "$DATABASE_URL" ]; then
            echo "DATABASE_URL not set in .env file. Please enter the required information:"
            read -p "Database name: " DB_NAME
            read -p "Database host: " DB_HOST
            read -p "Database port: " DB_PORT
            read -p "Database username: " DB_USER
            read -sp "Database password: " DB_PASS
            echo
        else
            PROTOCOL="$(echo $DATABASE_URL | awk -F '://' '{print $1}')"
            URL="$(echo $DATABASE_URL | awk -F '://' '{print $2}')"
            USERPASS="$(echo $URL | awk -F '@' '{print $1}')"
            HOSTPORT_DB="$(echo $URL | awk -F '@' '{print $2}')"

            USER="$(echo $USERPASS | awk -F ':' '{print $1}')"
            PASS="$(echo $USERPASS | awk -F ':' '{print $2}')"
            HOSTPORT="$(echo $HOSTPORT_DB | awk -F '/' '{print $1}')"
            DB_NAME="$(echo $HOSTPORT_DB | awk -F '/' '{print $2}')"
            
            HOST="$(echo $HOSTPORT | awk -F ':' '{print $1}')"
            PORT="$(echo $HOSTPORT | awk -F ':' '{print $2}')"
            
            DB_USER="$(urldecode $USER)"
            DB_PASS="$(urldecode $PASS)"
            DB_HOST="$HOST"
            DB_PORT="${PORT:-3306}" # default MySQL port
        fi
    fi

    echo "Database credentials:"
    echo "  Database name: $DB_NAME"
    echo "  Database host: $DB_HOST"
    echo "  Database port: $DB_PORT"
    echo "  Database username: $DB_USER"
    echo "  Database password: $DB_PASS"

    cd ~/../../web/shopware_cli
    ./shopware-cli project dump $DB_NAME --host $DB_HOST --port $DB_PORT --username $DB_USER --password $DB_PASS --clean --skip-lock-tables
}

create_file_backup() {
    echo "Creating backup of $SHOP_DIR directory..."
    tar cfvz shop.tar.gz -C "$SHOP_DIR" .
}

transfer_files() {
    echo "Transferring files using SCP..."
    read -p "Enter username for SCP: " SCP_USER
    read -sp "Enter password for SCP: " SCP_PASS
    echo

    scp shop.tar.gz $SCP_USER@$SCP_HOST:$SCP_DESTINATION_PATH
    scp dump.sql $SCP_USER@$SCP_HOST:$SCP_DESTINATION_PATH
    echo "Files transferred successfully."
}

while getopts ":s:u:h:d:" opt; do
    case ${opt} in
        s)
            SHOP_DIR="$PWD/$OPTARG"
            ;;
        u)
            SCP_USER=$OPTARG
            ;;
        h)
            SCP_HOST=$OPTARG
            ;;
        d)
            SCP_DESTINATION_PATH=$OPTARG
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
    esac
done
shift $((OPTIND -1))
download_shopware_cli
create_mysql_backup
create_file_backup
#transfer_files

echo "Backup and file transfer completed."
