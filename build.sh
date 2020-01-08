#!/usr/bin/env

set -e

ETCD_VERSION=${1}

if [ -z "${ETCD_VERSION}" ]; then
    echo "WARN: etcd version not specified, use default version 3.3.18."
    ETCD_VERSION="3.3.18"
fi

if [ ! -f "etcd-v${ETCD_VERSION}-linux-amd64.tar.gz" ]; then
    echo "INFO: downloading etcd precompiled binary."
    wget https://github.com/coreos/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz
fi

echo "INFO: extract the files."
tar -zxf etcd-v${ETCD_VERSION}-linux-amd64.tar.gz
cp etcd-v${ETCD_VERSION}-linux-amd64/etcd* usr/bin
rm -rf etcd-v${ETCD_VERSION}-linux-amd64

echo "INFO: building deb package."
rm -f *.deb
fpm -s dir -t deb -n etcd \
    -v ${ETCD_VERSION} \
    --vendor "mritd <mritd@linux.com>" \
    --maintainer "mritd <mritd@linux.com>" \
    --license "Apache License 2.0" \
    --description "etcd - highly-available key value store" \
    --url https://github.com/coreos/etcd \
    --before-install scripts/before-install.sh \
    --post-uninstall scripts/post-uninstall.sh \
    --deb-systemd lib/systemd/system/etcd.service \
    --deb-systemd-enable \
    --no-deb-systemd-auto-start \
    --no-deb-systemd-restart-after-upgrade \
    usr etc 

rm -f usr/bin/*

echo "INFO: success."
