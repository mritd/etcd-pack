#!/bin/sh
set -e

# Stop and disable service if systemd is available
if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active --quiet etcd.service; then
        systemctl stop etcd.service
    fi
    systemctl disable etcd.service || true
fi
