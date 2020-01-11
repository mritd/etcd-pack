#!/usr/bin/env

set -e

VERSION=$(cat version)

check_version(){
    if [ -z "${VERSION}" ]; then
        _warn "WARN: etcd version not specified, use default version 3.3.18."
        VERSION="3.3.18"
    fi
}

download(){
    if [ ! -f "etcd-v${VERSION}-linux-amd64.tar.gz" ]; then
        _info "INFO: downloading etcd precompiled binary."
        wget https://github.com/coreos/etcd/releases/download/v${VERSION}/etcd-v${VERSION}-linux-amd64.tar.gz
    fi

    _info "INFO: extract the files."
    tar -zxf etcd-v${VERSION}-linux-amd64.tar.gz
    cp etcd-v${VERSION}-linux-amd64/etcd* usr/bin
}

build_deb(){
    _info "INFO: building deb package."
    fpm -s dir -t deb -n etcd \
        -v ${VERSION} \
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
}

clean(){
    _info "INFO: clean files."
    rm -rf usr/bin/* etcd-v${VERSION}-linux-amd64*
}

_warn(){
    echo -e "\033[33m$*\033[0m"
}

_info(){
    echo -e "\033[32m$*\033[0m"
}

_error(){
    echo -e "\033[31m$*\033[0m"
}

check_version
download
build_deb
clean
