#!/bin/sh
set -e

# Detect package manager and removal type
# - deb: $1 = remove|purge|upgrade|...
# - rpm: $1 = 0 (uninstall) | 1 (upgrade)
# - apk: no args, check ETCD_PURGE env var for purge behavior

is_purge() {
    # deb purge
    [ "$1" = "purge" ] && return 0
    # rpm uninstall (not upgrade) with ETCD_PURGE env
    [ "$1" = "0" ] && [ "${ETCD_PURGE:-}" = "1" ] && return 0
    # apk with ETCD_PURGE env
    [ -z "$1" ] && [ "${ETCD_PURGE:-}" = "1" ] && return 0
    return 1
}

is_upgrade() {
    # deb upgrade
    [ "$1" = "upgrade" ] && return 0
    # rpm upgrade
    [ "$1" = "1" ] && return 0
    return 1
}

# Skip cleanup on upgrade
if is_upgrade "$1"; then
    exit 0
fi

if is_purge "$1"; then
    # Remove etcd user and group
    if id -u etcd >/dev/null 2>&1; then
        if command -v userdel >/dev/null 2>&1; then
            userdel etcd || true
        elif command -v deluser >/dev/null 2>&1; then
            # Alpine Linux
            deluser etcd || true
            delgroup etcd 2>/dev/null || true
        fi
    fi
    # Remove config directory
    rm -rf /etc/etcd
    # Remove data directory
    rm -rf /var/lib/etcd
    echo "etcd purged completely."
else
    # Normal remove - keep config and data
    echo "etcd removed. Config and data preserved."
    echo "  - Config: /etc/etcd/"
    echo "  - Data: /var/lib/etcd/"
    echo "  - To purge completely:"
    echo "      deb: apt purge etcd"
    echo "      rpm: ETCD_PURGE=1 rpm -e etcd"
    echo "      apk: ETCD_PURGE=1 apk del etcd"
fi

# Reload systemd if available
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload
fi
