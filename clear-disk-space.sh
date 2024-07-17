#!/bin/bash

function show_disk_usage {
    echo "Festplattenbelegung für den Ordner $1:"
    du -sh "$1"
}

function delete_files {
    read -p "Möchten Sie alle .tar.gz und .sql Dateien im Ordner $1 rekursiv löschen? (j/n): " answer
    if [[ "$answer" == "j" || "$answer" == "J" ]]; then
        find "$1" -type f \( -name "*.tar.gz" -o -name "*.sql" \) -exec rm -f {} \;
        echo "Alle .tar.gz und .sql Dateien wurden gelöscht."
    else
        echo "Keine Dateien wurden gelöscht."
    fi
}

if [ -z "$1" ]; then
    echo "Bitte geben Sie den Pfad zu einem Ordner als Argument an."
    exit 1
fi

show_disk_usage "$1"

delete_files "$1"

show_disk_usage "$1"
