#!/bin/bash

# Konfiguration
BACKUP_DRIVES=("/media/$USER/$DRIVE_NAME") #/media/sschleef/Crucial X8")  # Pfade anpassen
SOURCE_DIR="$HOME"                                   # Zu sicherndes Verzeichnis
SCRIPT_NAME=$(basename "$0")
EXCLUDE_FILE="$(dirname "$0")/backup-exclude.txt"  # Exclude-Datei im gleichen Verzeichnis
HOSTNAME="$(cat /etc/hostname)"

# Terminal-Überprüfung
if [ ! -t 0 ]; then
    # Wenn nicht im Terminal ausgeführt, Script in neuem Terminal starten
    x-terminal-emulator -e "$0"
    exit 0
fi

# Funktion zur Überprüfung, ob ein Laufwerk eingehängt ist
check_drive() {
    if ! mountpoint -q "$1"; then
        return 1
    fi
    return 0
}

# Prüfen ob Exclude-Datei existiert
if [ ! -f "$EXCLUDE_FILE" ]; then
    echo "Erstelle Exclude-Datei: $EXCLUDE_FILE"
    cat > "$EXCLUDE_FILE" << 'EOF'
.cache
.cache/**
*.tmp
.Trash
.Trash/**
lost+found
EOF
fi

# Funktion zur Erstellung des Backups
create_backup() {
    local DEST_BASE="$1"
    local TODAY=$(date +%Y-%m-%d)
    local BACKUP_DIR="$DEST_BASE/backups/$HOSTNAME/$TODAY"
    local LATEST_LINK="$DEST_BASE/backups/$HOSTNAME/latest"
    
    # Prüfen, ob bereits ein Backup von heute existiert
    if [ -d "$BACKUP_DIR" ]; then
        echo -e "\nBackup-Verzeichnis für heute existiert bereits: $BACKUP_DIR"
        read -p "Möchten Sie das heutige Backup überschreiben? [J/n]: " response
        if [[ "$response" =~ ^[Nn]$ ]]; then
            return 1
        fi
    else
        mkdir -p "$BACKUP_DIR"
    fi

    # Backup mit rsync erstellen
    echo -e "\nErstelle Backup in: $BACKUP_DIR"
    rsync $2 -av --progress --info=progress2 \
          --delete \
          --link-dest="$LATEST_LINK" \
          --exclude-from="$EXCLUDE_FILE" \
          "$SOURCE_DIR/" "$BACKUP_DIR/"

    # Latest-Link aktualisieren
    rm -f "$LATEST_LINK"
    ln -s "$BACKUP_DIR" "$LATEST_LINK"
    
    return 0
}

# Rest des Scripts bleibt unverändert...
# Bildschirm leeren und Header anzeigen
clear
echo "====================================="
echo "      Duales Backup-System          "
echo "====================================="

# Root-Rechte überprüfen
if [ "$(id -u)" = "0" ]; then
    echo "Warnung: Ausführung als Root wird nicht empfohlen!"
    read -p "Trotzdem fortfahren? [J/n]: " response
    if [[ "$response" =~ ^[Nn]$ ]]; then
        exit 1
    fi
fi

# Quellverzeichnis überprüfen
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Fehler: Quellverzeichnis $SOURCE_DIR existiert nicht!"
    exit 1
fi

# Backup-Laufwerke überprüfen
AVAILABLE_DRIVES=()
for drive in "${BACKUP_DRIVES[@]}"; do
    if check_drive "$drive"; then
        AVAILABLE_DRIVES+=("$drive")
        echo -e "\n✓ Backup-Laufwerk eingehängt: $drive"
        
        # Letztes Backup-Datum anzeigen, falls vorhanden
        LATEST_LINK="$drive/backups/$HOSTNAME/latest"
        if [ -L "$LATEST_LINK" ]; then
            LAST_BACKUP=$(basename "$(readlink -f "$LATEST_LINK")")
            echo "  Letztes Backup auf diesem Laufwerk: $LAST_BACKUP"
        else
            echo "  Kein vorheriges Backup auf diesem Laufwerk gefunden"
        fi
    else
        echo -e "\n✗ Backup-Laufwerk nicht eingehängt: $drive"
    fi
done

# Prüfen, ob mindestens ein Laufwerk verfügbar ist
if [ ${#AVAILABLE_DRIVES[@]} -eq 0 ]; then
    echo -e "\nFehler: Keine Backup-Laufwerke sind eingehängt!"
    echo "Bitte hängen Sie mindestens eines dieser Laufwerke ein:"
    printf '%s\n' "${BACKUP_DRIVES[@]}"
    read -p "Drücken Sie Enter zum Beenden..."
    exit 1
fi

# Backup bestätigen
echo -e "\nBereit zum Backup von $SOURCE_DIR auf ${#AVAILABLE_DRIVES[@]} Laufwerk(e)"
read -p "Backup starten? [J/n]: " response
if [[ "$response" =~ ^[Nn]$ ]]; then
    exit 0
fi

# Backup auf allen verfügbaren Laufwerken durchführen
for drive in "${AVAILABLE_DRIVES[@]}"; do
    echo -e "\nFühre Backup durch auf: $drive"
    if create_backup "$drive" $1; then
        echo "✓ Backup erfolgreich abgeschlossen auf $drive"
    else
        echo "✗ Backup fehlgeschlagen oder abgebrochen für $drive"
    fi
done

echo -e "\nAlle Backup-Vorgänge abgeschlossen!"
read -p "Drücken Sie Enter zum Beenden..."
