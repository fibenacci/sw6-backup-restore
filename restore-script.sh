#!/bin/bash


SHOPWARE_PATH="/pfad/zu/deiner/shopware/installation"

if [ ! -d "$SHOPWARE_PATH" ]; then
  echo "Der angegebene Pfad zur Shopware-Installation existiert nicht: $SHOPWARE_PATH"
  exit 1
fi

cd "$SHOPWARE_PATH" || exit

bin/console system:config:set core.mailerSettings.emailAgent ""
bin/console system:config:set core.mailerSettings.disableDelivery "true"

bin/console cache:clear

echo "Mailer-Einstellungen in Shopware 6 wurden deaktiviert."

DATABASE_URL=$(grep -E "^DATABASE_URL=" .env.local | cut -d '=' -f 2-)

if [ -z "$DATABASE_URL" ]; then
  echo "DATABASE_URL wurde in der .env.local Datei nicht gefunden."
  exit 1
fi

proto="$(echo $DATABASE_URL | sed -e's,^\(.*\)://.*,\1,g')"
user="$(echo $DATABASE_URL | sed -e 's,^.*://\([^:]*\):.*,\1,g')"
pass_enc="$(echo $DATABASE_URL | sed -e 's,^.*://[^:]*:\([^@]*\)@.*,\1,g')"
host="$(echo $DATABASE_URL | sed -e 's,^.*@\(.*\):.*,\1,g')"
port="$(echo $DATABASE_URL | sed -e 's,^.*:\(.*\)/.*,\1,g')"
dbname="$(echo $DATABASE_URL | sed -e 's,^.*/\([^?]*\).*,\1,g')"

pass=$(python3 -c "import urllib.parse; print(urllib.parse.unquote('$pass_enc'))")

read -p "Bitte geben Sie den Pfad zur SQL-Datei ein: " SQL_FILE

if [ ! -f "$SQL_FILE" ]; then
  echo "Die angegebene SQL-Datei existiert nicht: $SQL_FILE"
  exit 1
fi

mysql --user="$user" --password="$pass" --host="$host" --port="$port" "$dbname" < "$SQL_FILE"

echo "SQL-Datei wurde erfolgreich in die Datenbank eingespielt."

read -p "Bitte geben Sie die neue Basis-URL für die Verkaufskanäle ein (z.B. https://neue-domain.de): " NEW_BASE_URL

if [ -z "$NEW_BASE_URL" ]; then
  echo "Keine gültige URL eingegeben. Das Skript wird beendet."
  exit 1
fi

bin/console sales-channel:update:domain --all --url "$NEW_BASE_URL"

echo "Die URLs der Verkaufskanäle wurden erfolgreich angepasst."

bin/console cache:clear

echo "Der Cache wurde erfolgreich geleert."
