#!/usr/bin/env bash

set -e

VERSION=${1}

check_version(){
    if [ -z "${VERSION}" ]; then
        warn "etcd version not specified, use default version 3.4.14."
        VERSION="3.4.14"
    fi
}

download(){
    info "downloading etcd precompiled binary."
    wget https://github.com/coreos/etcd/releases/download/v${VERSION}/etcd-v${VERSION}-linux-amd64.tar.gz

    info "extract the files."
    tar -zxf etcd-v${VERSION}-linux-amd64.tar.gz
    cp etcd-v${VERSION}-linux-amd64/etcd* pack/bin/
}

pre_build(){
    if ! command -v makeself.sh >/dev/null 2>&1; then
        wget https://github.com/megastep/makeself/releases/download/release-2.4.3/makeself-2.4.3.run
        bash makeself-2.4.3.run
        export PATH=${PATH}:$(pwd)/makeself-2.4.3
    fi
}

build(){
    info "building..."
    cat > LSM <<EOF
Begin4
Title:          etcd
Version:        ${VERSION}
Description:    highly-available key value store
Keywords:       etcd kv
Author:         The etcd Authors
Maintained-by:  mritd (mritd@linux.com)
Original-site:  https://github.com/etcd-io/etcd
Platform:       Linux
Copying-policy: Apache-2.0
End
EOF
    makeself.sh --lsm LSM pack etcd_v${VERSION}.run "etcd - highly-available key value store" ./helper.sh etcd_v${VERSION}.run
}

clean(){
    info "clean files."
    rm -rf pack/bin/* etcd-v${VERSION}-linux-amd64* makeself-2.4.3* LSM
}

function info(){
    echo -e "\033[1;32mINFO: $@\033[0m"
}

function warn(){
    echo -e "\033[1;33mWARN: $@\033[0m"
}

function err(){
    echo -e "\033[1;31mERROR: $@\033[0m"
}

check_version
download
pre_build
build
clean

