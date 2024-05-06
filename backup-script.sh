#!/bin/bash

# Default values
SHOP_DIR="shop"

# Function to show usage information
usage() {
    echo "Usage: $0 [-s shop_dir] [-u username] [-h host] [-d destination_path]"
    echo "Options:"
    echo "  -s    Specify the shop directory (default: shop)"
    echo "  -u    Specify the username for SCP"
    echo "  -h    Specify the host for SCP"
    echo "  -d    Specify the destination path on the remote server"
    exit 1
}

# Function to download and configure Shopware CLI Tools
download_shopware_cli() {
    echo "Downloading and configuring Shopware CLI Tools..."
    cd ~/../../web/
    mkdir -p shopware_cli && cd shopware_cli
    wget https://github.com/FriendsOfShopware/shopware-cli/releases/download/0.4.19/shopware-cli_Linux_x86_64.tar.gz
    tar xfvz shopware-cli_Linux_x86_64.tar.gz
    rm shopware-cli_Linux_x86_64.tar.gz
    ./shopware-cli project config init
}

# Function to create MySQL backup using Shopware CLI Tools
create_mysql_backup() {
    echo "Creating MySQL backup using Shopware CLI Tools..."
    echo "Please enter the required information:"
    read -p "Database name: " DB_NAME
    read -p "Database host: " DB_HOST
    read -p "Database port: " DB_PORT
    read -p "Database username: " DB_USER
    read -sp "Database password: " DB_PASS
    echo

    cd ~/../../web/shopware_cli
    ./shopware-cli project dump $DB_NAME --host $DB_HOST --port $DB_PORT --username $DB_USER --password $DB_PASS --clean --skip-lock-tables
}

# Function to transfer files using SCP
transfer_files() {
    echo "Transferring files using SCP..."
    read -p "Enter username for SCP: " SCP_USER
    read -sp "Enter password for SCP: " SCP_PASS
    echo

    scp shop.tar.gz $SCP_USER@$SCP_HOST:$SCP_DESTINATION_PATH
    scp dump.sql $SCP_USER@$SCP_HOST:$SCP_DESTINATION_PATH
    echo "Files transferred successfully."
}

# Parse command-line options
while getopts ":s:u:h:d:" opt; do
    case ${opt} in
        s)
            SHOP_DIR=$OPTARG
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

# Download and configure Shopware CLI Tools
download_shopware_cli

# Backup shop directory
echo "Creating backup of $SHOP_DIR directory..."
tar cfvz shop.tar.gz $SHOP_DIR/

# Create MySQL backup if specified
create_mysql_backup

# Transfer files using SCP
transfer_files

echo "Backup and file transfer completed."
