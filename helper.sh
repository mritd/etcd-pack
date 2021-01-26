#!/usr/bin/env bash

set -e

BIN_ETCD="/usr/bin/etcd"
BIN_ETCDCTL="/usr/bin/etcdctl"
CONFIG_DIR="/etc/etcd"
DATA_DIR="/var/lib/etcd"
SYSTEMD_SERVICE="/lib/systemd/system/etcd.service"
BACKUP_SUFFIX=$(date "+%Y%m%d%H%M%S")


function install(){
    info "install etcd..."
    backup
    add_user
    info "copy files..."
    cp bin/etcd ${BIN_ETCD}
    cp bin/etcdctl ${BIN_ETCDCTL}
    cp -r config ${CONFIG_DIR}
    cp etcd.service ${SYSTEMD_SERVICE}
    fix_permissions

    info "systemd reload..."
    systemctl daemon-reload
}

function uninstall(){
    warn "uninstall etcd..."
    systemctl stop ectd
    del_user
    warn "remove files..."
    rm -f ${BIN_ETCD} ${BIN_ETCDCTL} ${SYSTEMD_SERVICE}
    info "systemd reload..."
    systemctl daemon-reload
}

function purge(){
    warn "purge etcd..."
    systemctl stop ectd
    del_user
    rm -rf ${BIN_ETCD} ${BIN_ETCDCTL} ${SYSTEMD_SERVICE} ${CONFIG_DIR} ${DATA_DIR}
    systemctl daemon-reload
}

function backup(){
    info "backup files..."
    if [ -f ${BIN_ETCD} ]; then
        warn "backup ${BIN_ETCD} to ${BIN_ETCD}.${BACKUP_SUFFIX}..."
        mv ${BIN_ETCD} ${BIN_ETCD}.${BACKUP_SUFFIX}
    fi
    if [ -f ${BIN_ETCDCTL} ]; then
        warn "backup ${BIN_ETCDCTL} to ${BIN_ETCDCTL}.${BACKUP_SUFFIX}..."
        mv ${BIN_ETCDCTL} ${BIN_ETCDCTL}.${BACKUP_SUFFIX}
    fi
    if [ -f ${SYSTEMD_SERVICE} ]; then
        warn "backup ${SYSTEMD_SERVICE} to ${SYSTEMD_SERVICE}.${BACKUP_SUFFIX}..."
        mv ${SYSTEMD_SERVICE} ${SYSTEMD_SERVICE}.${BACKUP_SUFFIX}
    fi
    if [ -d ${CONFIG_DIR} ]; then
        warn "backup ${CONFIG_DIR} to ${CONFIG_DIR}.${BACKUP_SUFFIX}"
        mv ${CONFIG_DIR} ${CONFIG_DIR}.${BACKUP_SUFFIX}
    fi
    if [ -d ${DATA_DIR} ]; then
        warn "backup ${DATA_DIR} to ${DATA_DIR}.${BACKUP_SUFFIX}"
        mv ${DATA_DIR} ${DATA_DIR}.${BACKUP_SUFFIX}
    fi
}

function add_user(){
    info "add etcd user..."
    if ! getent passwd etcd > /dev/null 2>&1 ; then
        adduser --system --group --disabled-login --disabled-password --home /var/lib/etcd/ etcd
    fi
}

function del_user(){
    warn "delete etcd user..."
    if getent passwd etcd > /dev/null 2>&1 ; then
        deluser --system etcd
    fi
}


function fix_permissions(){
    info "fix permissions..."
    chmod 755 ${BIN_ETCD} ${BIN_ETCDCTL} ${CONFIG_DIR} ${DATA_DIR}
    chmod 644 ${SYSTEMD_SERVICE}

    chown -R etcd:etcd ${BIN_ETCD} ${BIN_ETCDCTL} ${CONFIG_DIR} ${DATA_DIR}
    chmod root:root ${SYSTEMD_SERVICE}
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

case "${1}" in
    "install")
        install
        ;;
    "uninstall")
        uninstall
        ;;
    "purge")
        purge
        ;;
    *)
        error "Unknown subcommand!"
        exit 1
        ;;
esac

