#!/bin/bash

# === CONFIGURATION ===
REMOTE_USER="$USER"
REMOTE_HOST="127.0.0.1"
REMOTE_DIR="/backups/$(cat /etc/hostname)/$USER"
LOCAL_SOURCE="/home/$USER/"
EXCLUDE_FILE="backup-exclude.txt"
