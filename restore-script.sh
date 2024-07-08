#!/bin/bash

# Pfad zu deiner Shopware-Installation
SHOPWARE_PATH="/pfad/zu/deiner/shopware/installation"

# Prüfen, ob der Pfad zur Shopware-Installation existiert
if [ ! -d "$SHOPWARE_PATH" ]; then
  echo "Der angegebene Pfad zur Shopware-Installation existiert nicht: $SHOPWARE_PATH"
  exit 1
fi

# In das Shopware-Verzeichnis wechseln
cd "$SHOPWARE_PATH" || exit

# Mailer deaktivieren
bin/console system:config:set core.mailerSettings.emailAgent "null"
bin/console system:config:set core.mailerSettings.disableDelivery "true"

# Änderungen anwenden
bin/console cache:clear

echo "Mailer-Einstellungen in Shopware 6 wurden deaktiviert."

# .env.local Datei einlesen und DATABASE_URL extrahieren
DATABASE_URL=$(grep -E "^DATABASE_URL=" .env.local | cut -d '=' -f 2-)

# Prüfen, ob die DATABASE_URL gefunden wurde
if [ -z "$DATABASE_URL" ]; then
  echo "DATABASE_URL wurde in der .env.local Datei nicht gefunden."
  exit 1
fi

# DATABASE_URL parsen
proto="$(echo $DATABASE_URL | sed -e's,^\(.*\)://.*,\1,g')"
user="$(echo $DATABASE_URL | sed -e 's,^.*://\([^:]*\):.*,\1,g')"
pass_enc="$(echo $DATABASE_URL | sed -e 's,^.*://[^:]*:\([^@]*\)@.*,\1,g')"
host="$(echo $DATABASE_URL | sed -e 's,^.*@\(.*\):.*,\1,g')"
port="$(echo $DATABASE_URL | sed -e 's,^.*:\(.*\)/.*,\1,g')"
dbname="$(echo $DATABASE_URL | sed -e 's,^.*/\([^?]*\).*,\1,g')"

# URL-decodiertes Passwort
pass=$(python3 -c "import urllib.parse; print(urllib.parse.unquote('$pass_enc'))")

# SQL-Datei abfragen
read -p "Bitte geben Sie den Pfad zur SQL-Datei ein: " SQL_FILE

# Prüfen, ob die SQL-Datei existiert
if [ ! -f "$SQL_FILE" ]; then
  echo "Die angegebene SQL-Datei existiert nicht: $SQL_FILE"
  exit 1
fi

# SQL-Datei in die Datenbank einspielen
mysql --user="$user" --password="$pass" --host="$host" --port="$port" "$dbname" < "$SQL_FILE"

echo "SQL-Datei wurde erfolgreich in die Datenbank eingespielt."

# URLs der Verkaufskanäle anpassen
read -p "Bitte geben Sie die neue Basis-URL für die Verkaufskanäle ein (z.B. https://neue-domain.de): " NEW_BASE_URL

if [ -z "$NEW_BASE_URL" ]; then
  echo "Keine gültige URL eingegeben. Das Skript wird beendet."
  exit 1
fi

# Verkaufskanäle aktualisieren
bin/console sales-channel:update:domain --all --url "$NEW_BASE_URL"

echo "Die URLs der Verkaufskanäle wurden erfolgreich angepasst."

# Cache leeren
bin/console cache:clear

echo "Der Cache wurde erfolgreich geleert."
