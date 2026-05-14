#!/bin/bash

# === CONFIGURATION ===
source config.sh

# === Derived variables ===
TODAY=$(date +%F)
SSH_CONN="$REMOTE_USER@$REMOTE_HOST"
DATE_REGEX='[0-9]{4}-[0-9]{2}-[0-9]{2}'

# === Find the latest backup on the remote ===
echo "Checking for previous backups on $SSH_CONN..."

LATEST_BACKUP=$(sftp "$SSH_CONN" <<EOF | grep -E "$DATE_REGEX" | sort -r | head -n 1
ls $REMOTE_DIR
EOF
)

if [ -n "$LATEST_BACKUP" ]; then
    echo "Found previous backup: $LATEST_BACKUP"
else
    echo "No previous backup found."
fi

echo -n "Start new backup to $TODAY? Press Enter to continue or Ctrl+C to cancel..."
read

# === Set remote target path ===
REMOTE_TARGET="$REMOTE_DIR/$TODAY"

# === Build rsync options ===
RSYNC_OPTS="-av --progress --info=progress2 --delete -e ssh"

# Add --link-dest if previous backup exists
if [ -n "$LATEST_BACKUP" ]; then
    LATEST_FOLDER_NAME=$(basename "$LATEST_BACKUP")
    RELATIVE_LINK_DEST="../$LATEST_FOLDER_NAME"
    RSYNC_OPTS="$RSYNC_OPTS --link-dest=$RELATIVE_LINK_DEST"
fi

# Add exclude file if it exists
if [ -f "$EXCLUDE_FILE" ]; then
    RSYNC_OPTS="$RSYNC_OPTS --exclude-from=$EXCLUDE_FILE"
    echo "Using exclude file: $EXCLUDE_FILE"
fi

# Create destination folder on remote using SFTP
echo "Creating backup directory: $REMOTE_DIR/$TODAY via SFTP..."
sftp "$SSH_CONN" <<EOF
mkdir $REMOTE_DIR/$TODAY
EOF


# === Perform rsync backup ===
echo "Starting rsync with options:"
echo "  $RSYNC_OPTS"
rsync $RSYNC_OPTS "$LOCAL_SOURCE/" "$SSH_CONN::$REMOTE_TARGET/"

echo "Backup to $REMOTE_TARGET completed."
