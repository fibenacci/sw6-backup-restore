#!/bin/bash

SHOP_DIR="$PWD/shop"
SCP_HOST="176.9.130.42"
SCP_USER="webv_bucket_ssh"
SCP_DESTINATION_PATH="/var/www/clients/client6/web10/home/webv_bucket_ssh/"

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

get_domain_name() {
    ENV_FILE="$SHOP_DIR/.env.local"
    if [ -f "$ENV_FILE" ]; then
        DOMAIN_NAME=$(grep 'APP_URL' "$ENV_FILE" | cut -d'=' -f2 | awk -F[/:] '{print $4}')
        echo "$DOMAIN_NAME"
    else
        echo "domain_not_found"
    fi
}

create_anonymization_file() {
    DOMAIN_NAME=$(get_domain_name)
    cat > .shopware-project.yml <<EOL
url: $DOMAIN_NAME
dump: 
# rewrite columns 
 rewrite: 
  user:
    first_name: "faker.Person.FirstName()"
    last_name: "faker.Person.LastName()"
    email: "faker.Internet.Email()"  
  customer:
    first_name: "faker.Person.FirstName()"
    last_name: "faker.Person.LastName()"
    company: "faker.Person.Name()"
    title: "faker.Person.Name()"
    email: "faker.Internet.Email()"
    remote_address: "faker.Internet.Ipv4()"
  customer_address: 
    first_name: "faker.Person.FirstName()"
    last_name: "faker.Person.LastName()"
    company: "faker.Person.Name()"
    title: "faker.Person.Name()"
    street: "faker.Address.StreetAddress()"
    zipcode: "faker.Address.PostCode()"
    city: "faker.Address.City()"
    phone_number: "faker.Phone.Number()"
  log_entry:
    provider: ""
  newsletter_recipient:
    email: "faker.Internet.Email()"
    first_name: "faker.Person.FirstName()"
    last_name: "faker.Person.LastName()"
    city: "faker.Address.City()"
  order_address:
    first_name: "faker.Person.FirstName()"
    last_name: "faker.Person.LastName()"
    company: "faker.Person.Name()"
    title: "faker.Person.Name()"
    street: "faker.Address.StreetAddress()"
    zipcode: "faker.Address.PostCode()"
    city: "faker.Address.City()"
    phone_number: "faker.Phone.Number()"
  order_customer:
    first_name: "faker.Person.FirstName()"
    last_name: "faker.Person.LastName()"
    company: "faker.Person.Name()"
    title: "faker.Person.Name()"
    email: "faker.Internet.Email()"
    remote_address: "faker.Internet.Ipv4()"
  product_review:
    email: "faker.Internet.Email()"
EOL
}

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
        
        if [ -z "$DATABASE_URL" ];then
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
            DB_PORT="${PORT:-3306}"
        fi
    fi

    echo "Database credentials:"
    echo "  Database name: $DB_NAME"
    echo "  Database host: $DB_HOST"
    echo "  Database port: $DB_PORT"
    echo "  Database username: $DB_USER"
    echo "  Database password: $DB_PASS"

    cd ~/../../web/shopware_cli

    read -p "Do you want to anonymize the data? (y/n): " anonymize_data
    if [ "$anonymize_data" == "y" ]; then
        create_anonymization_file
    fi

    ./shopware-cli project dump $DB_NAME --host $DB_HOST --port $DB_PORT --username $DB_USER --password $DB_PASS --clean --skip-lock-tables

    DOMAIN_NAME=$(get_domain_name)
    CURRENT_USER=$(whoami)
    mv dump.sql "${DOMAIN_NAME}_${CURRENT_USER}_dump.sql"
}

create_file_backup() {
    echo "Creating backup of $SHOP_DIR directory..."
    tar cfvz shop.tar.gz --exclude=shop/ageverification_archive --exclude=shop/**/AgeVerification_* --exclude=shop/var/cache/* --exclude=shop/var/log/* -C "$SHOP_DIR" .
    
    DOMAIN_NAME=$(get_domain_name)
    CURRENT_USER=$(whoami)
    mv shop.tar.gz "${DOMAIN_NAME}_${CURRENT_USER}_shop.tar.gz"
}

transfer_files() {
    echo "Transferring files using SCP..."
    read -p "Enter username for SCP: " SCP_USER
    read -sp "Enter password for SCP: " SCP_PASS
    echo

    DOMAIN_NAME=$(get_domain_name)
    CURRENT_USER=$(whoami)

    scp "${DOMAIN_NAME}_${CURRENT_USER}_shop.tar.gz" $SCP_USER@$SCP_HOST:$SCP_DESTINATION_PATH
    scp "${DOMAIN_NAME}_${CURRENT_USER}_dump.sql" $SCP_USER@$SCP_HOST:$SCP_DESTINATION_PATH
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

read -p "Do you want to create a MySQL backup? (y/n): " create_mysql_backup
if [ "$create_mysql_backup" == "y" ]; then
    create_mysql_backup
fi

read -p "Do you want to create a file backup? (y/n): " create_file_backup
if [ "$create_file_backup" == "y" ]; then
    create_file_backup
fi

read -p "Do you want to transfer files via SCP? (y/n): " transfer_files
if [ "$transfer_files" == "y" ]; then
    transfer_files
fi

echo "Backup and file transfer completed."
