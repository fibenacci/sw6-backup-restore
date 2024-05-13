#!/bin/bash
CURRENT_DIR="$PWD"
CURRENT_FOLDER=$(basename "$PWD")
bin/console sales-channel:maintenance:enable --all
cd ..
tar cfvz live-backup.tar.gz $CURRENT_FOLDER
cd $CURRENT_DIR

ENV_FILE=".env.local"
if [ ! -f "$ENV_FILE" ]; then
  echo "Die Datei $ENV_FILE existiert nicht."
  exit 1
fi

urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }
while IFS= read -r line; do
  if [[ "$line" == *"DATABASE_URL="* ]]; then
    DATABASE_URL="${line#*=}"
    DATABASE_URL=$(urldecode "$DATABASE_URL")
    USER=$(echo "$DATABASE_URL" | awk -F'[/:@]' '{print $4}')
    PASSWORD=$(echo "$DATABASE_URL" | awk -F'[/:@]' '{print $5}')
    HOST=$(echo "$DATABASE_URL" | awk -F'[/:@]' '{print $6}')
    PORT=$(echo "$DATABASE_URL" | awk -F'[/:@]' '{print $7}')
    DATABASE=$(echo "$DATABASE_URL" | awk -F'[/:@]' '{print $8}')
    cd ..
    mysqldump -u "$USER" -p"$PASSWORD" -h "$HOST" -P "$PORT" "$DATABASE" > live-backup.sql
    cd $CURRENT_DIR
    if [ $? -eq 0 ]; then
      echo "Backup erfolgreich erstellt: live-backup.sql"
    else
      echo "Fehler beim Erstellen des Backups."
      exit 1
    fi
  fi
done < "$ENV_FILE"
git reset --hard
git pull
bin/console cache:clear
bin/console system:update:prepare
composer install
bin/cosole system:update:finish
bin/console plugin:refresh
bin/console plugin:install -r -n ""
bin/console plugin:update -r -n ""
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
cd ~
source .bashrc
nvm ls-remote
nvm install v18.17.1
cd $CURRENT_FOLDER
bin/build-administration.sh
bin/build-storefront.sh
bin/console assets:install
bin/console theme:compile
bin/console cache:clear
bin/console sales-channel:maintenance:disable --all
