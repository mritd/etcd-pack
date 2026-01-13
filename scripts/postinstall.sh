#!/bin/sh
set -e

# Create etcd system user and group if not exists
if ! id -u etcd >/dev/null 2>&1; then
    if command -v useradd >/dev/null 2>&1; then
        # Linux with useradd (Debian, RHEL, etc.)
        useradd --system --no-create-home --shell /usr/sbin/nologin etcd
    elif command -v adduser >/dev/null 2>&1; then
        # Alpine Linux - create group first, then user
        addgroup -S etcd 2>/dev/null || true
        adduser -S -D -H -G etcd -s /sbin/nologin etcd
    fi
fi

# Ensure data directory ownership (only if user exists)
if id -u etcd >/dev/null 2>&1; then
    chown -R etcd:etcd /var/lib/etcd
fi

# Reload and enable systemd service if available
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload
    systemctl enable etcd.service
fi

echo "etcd installed successfully."
echo "  - Edit config: /etc/etcd/etcd.yaml"
echo "  - Start service: systemctl start etcd"
