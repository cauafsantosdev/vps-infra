#!/usr/bin/env bash

set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "error: run this script as root"
    exit 1
fi

install -m 0644 \
    systemd/postgres-backup.service \
    /etc/systemd/system/postgres-backup.service

install -m 0644 \
    systemd/postgres-backup.timer \
    /etc/systemd/system/postgres-backup.timer

systemctl daemon-reload
systemctl enable --now postgres-backup.timer

systemctl list-timers postgres-backup.timer