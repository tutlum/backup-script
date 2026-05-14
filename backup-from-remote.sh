#!/bin/bash

# === CONFIGURATION ===
source config-pull.sh

# === Derived values ===
TODAY=$(date +%F)
DEST_DIR="$NAS_DEST/$TODAY"
DATE_REGEX='[0-9]{4}-[0-9]{2}-[0-9]{2}'
LOG_FILE="$NAS_DEST/log/backup-$TODAY.log"

echo "[$(date)] Starting backup from $REMOTE_HOST..." | tee -a "$LOG_FILE"

# === Find latest backup folder ===
LATEST_BACKUP=$(ls -1 "$NAS_DEST" | grep -E "$DATE_REGEX" |grep -v log | sort -r | head -n 1)


# === Check if the latest backup is already today's ===
if [ "$LATEST_BACKUP" == "$TODAY" ]; then
    echo "[$(date)] ℹ️ Backup for today ($TODAY) already exists. Skipping." | tee -a "$LOG_FILE"
    exit 0
fi

if [ -n "$LATEST_BACKUP" ]; then
    echo "Found previous backup: $LATEST_BACKUP" | tee -a "$LOG_FILE"
    LINK_DEST_OPT="--link-dest=../$LATEST_BACKUP"
else
    echo "No previous backup found. Performing full backup." | tee -a "$LOG_FILE"
    LINK_DEST_OPT=""
fi

# === Create new destination folder ===
echo mkdir -p "$DEST_DIR"

# === Build rsync command ===
RSYNC_CMD="rsync -a --delete-after -e 'ssh -c aes128-gcm@openssh.com'"

# Include exclude file if it exists
if [ -f "$EXCLUDE_FILE" ]; then
    RSYNC_CMD="$RSYNC_CMD --exclude-from=$EXCLUDE_FILE"
    echo "Using exclude file: $EXCLUDE_FILE" | tee -a "$LOG_FILE"
fi

# Add link-dest option if applicable
if [ -n "$LINK_DEST_OPT" ]; then
    RSYNC_CMD="$RSYNC_CMD $LINK_DEST_OPT"
fi

# === Final rsync command ===
RSYNC_CMD="$RSYNC_CMD $REMOTE_USER@$REMOTE_HOST:$REMOTE_SOURCE/ $DEST_DIR/"

echo "Running: $RSYNC_CMD" | tee -a "$LOG_FILE"

# === Execute the backup ===
echo eval $RSYNC_CMD >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "[$(date)] ✅ Backup completed successfully." | tee -a "$LOG_FILE"
else
    echo "[$(date)] ❌ Backup encountered errors!" | tee -a "$LOG_FILE"
fi
