#!/usr/bin/env bash

getent group etcd >/dev/null || groupadd -r etcd
getent passwd etcd >/dev/null || useradd -r -g etcd -d /var/lib/etcd -s /sbin/nologin -c "etcd user" etcd

if [ ! -d "/var/lib/etcd" ]; then
    mkdir /var/lib/etcd
    chown -R etcd:etcd /var/lib/etcd
fi
