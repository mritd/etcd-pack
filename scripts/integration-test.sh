#!/bin/bash
set -e

# Integration test script for etcd-pack
# Tests deb, rpm, and apk packages in Docker containers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

# Detect host architecture
HOST_ARCH=$(uname -m)
case "$HOST_ARCH" in
    x86_64)
        PKG_ARCH="amd64"
        RPM_ARCH="x86_64"
        APK_ARCH="x86_64"
        ;;
    aarch64|arm64)
        PKG_ARCH="arm64"
        RPM_ARCH="aarch64"
        APK_ARCH="aarch64"
        ;;
    *) log_error "Unsupported architecture: $HOST_ARCH"; exit 1 ;;
esac

# Build test images
build_images() {
    log_info "Building test images..."
    docker build -q -t etcd-test:deb -f "$SCRIPT_DIR/Dockerfile.deb" "$SCRIPT_DIR" >/dev/null
    docker build -q -t etcd-test:rpm -f "$SCRIPT_DIR/Dockerfile.rpm" "$SCRIPT_DIR" >/dev/null
    docker build -q -t etcd-test:apk -f "$SCRIPT_DIR/Dockerfile.apk" "$SCRIPT_DIR" >/dev/null
    log_info "Test images built"
}

# Test deb package
test_deb() {
    local pkg="$DIST_DIR/packages/etcd_*_${PKG_ARCH}.deb"
    local container="etcd-test-deb-$$"

    if ! ls $pkg >/dev/null 2>&1; then
        log_warn "No deb package found, skipping deb test"
        return 0
    fi

    log_info "Testing deb package..."

    docker run -d --name "$container" --privileged --cgroupns=host \
        -v /sys/fs/cgroup:/sys/fs/cgroup:rw etcd-test:deb >/dev/null

    sleep 3
    docker cp $pkg "$container:/tmp/etcd.deb"

    docker exec "$container" bash -c '
set -e
apt-get update -qq
apt-get install -y /tmp/etcd.deb

# Verify installation
which etcd && which etcdctl && which etcdutl
test -f /etc/etcd/etcd.yaml
test -d /var/lib/etcd

# Test service
systemctl start etcd.service
sleep 2
systemctl is-active etcd.service

# Test functionality
etcdctl put /test "hello"
[ "$(etcdctl get /test --print-value-only)" = "hello" ]

# Test remove (keep data)
systemctl stop etcd.service
apt-get remove -y etcd
test -d /var/lib/etcd
test -f /etc/etcd/etcd.yaml

# Test purge
apt-get install -y /tmp/etcd.deb
apt-get purge -y etcd
! test -d /var/lib/etcd
! test -d /etc/etcd
'

    docker rm -f "$container" >/dev/null
    log_success "deb package test passed"
}

# Test rpm package
test_rpm() {
    local pkg="$DIST_DIR/packages/etcd-*.${RPM_ARCH}.rpm"
    local container="etcd-test-rpm-$$"

    if ! ls $pkg >/dev/null 2>&1; then
        log_warn "No rpm package found, skipping rpm test"
        return 0
    fi

    log_info "Testing rpm package..."

    docker run -d --name "$container" --privileged --cgroupns=host \
        -v /sys/fs/cgroup:/sys/fs/cgroup:rw etcd-test:rpm >/dev/null

    sleep 3
    docker cp $pkg "$container:/tmp/etcd.rpm"

    docker exec "$container" bash -c '
set -e
dnf install -y /tmp/etcd.rpm

# Verify installation
which etcd && which etcdctl && which etcdutl
test -f /etc/etcd/etcd.yaml
test -d /var/lib/etcd

# Test service
systemctl start etcd.service
sleep 2
systemctl is-active etcd.service

# Test functionality
etcdctl put /test "hello"
[ "$(etcdctl get /test --print-value-only)" = "hello" ]

# Test remove (keep data)
systemctl stop etcd.service
dnf remove -y etcd
test -d /var/lib/etcd
test -f /etc/etcd/etcd.yaml

# Test purge
dnf install -y /tmp/etcd.rpm
ETCD_PURGE=1 rpm -e etcd
! test -d /var/lib/etcd
! test -d /etc/etcd
'

    docker rm -f "$container" >/dev/null
    log_success "rpm package test passed"
}

# Test apk package
test_apk() {
    local pkg="$DIST_DIR/packages/etcd_*_${APK_ARCH}.apk"
    local container="etcd-test-apk-$$"

    if ! ls $pkg >/dev/null 2>&1; then
        log_warn "No apk package found, skipping apk test"
        return 0
    fi

    log_info "Testing apk package..."

    docker run -d --name "$container" etcd-test:apk >/dev/null

    sleep 2
    docker cp $pkg "$container:/tmp/etcd.apk"

    docker exec "$container" sh -c '
set -e
apk add --allow-untrusted /tmp/etcd.apk

# Verify installation
which etcd && which etcdctl && which etcdutl
test -f /etc/etcd/etcd.yaml
test -d /var/lib/etcd

# Test functionality (no systemd in Alpine)
etcd &
sleep 3
etcdctl put /test "hello"
[ "$(etcdctl get /test --print-value-only)" = "hello" ]
pkill etcd || true

# Test remove (keep data)
apk del etcd
test -d /var/lib/etcd
test -f /etc/etcd/etcd.yaml

# Test purge
apk add --allow-untrusted /tmp/etcd.apk
ETCD_PURGE=1 apk del etcd
! test -d /var/lib/etcd
! test -d /etc/etcd
'

    docker rm -f "$container" >/dev/null
    log_success "apk package test passed"
}

# Cleanup
cleanup() {
    docker rm -f etcd-test-deb-$$ etcd-test-rpm-$$ etcd-test-apk-$$ 2>/dev/null || true
}

trap cleanup EXIT

# Main
log_info "Starting integration tests for $PKG_ARCH..."

build_images

FAILED=0

test_deb || FAILED=1
test_rpm || FAILED=1
test_apk || FAILED=1

echo ""
if [ $FAILED -eq 0 ]; then
    log_success "All integration tests passed!"
else
    log_fail "Some tests failed"
    exit 1
fi
