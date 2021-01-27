## etcd-pack

> 本仓库为 etcd 二进制文件生安装包，方便在宿主机安装以及配置。

### 一、使用

可直接从 [release](https://github.com/mritd/etcd-pack/releases) 页面下载对应版本安装包，然后执行 `etcd_*.run install` 既可安装。

```sh
➜ ./etcd_v3.4.14.run
Verifying archive integrity...  100%   MD5 checksums are OK. All good.
Uncompressing etcd - highly-available key value store  100%

NAME:
    etcd_v3.4.14.run - Etcd Install Tool

USAGE:
    etcd_v3.4.14.run command

AUTHOR:
    mritd <mritd@linux.com>

COMMANDS:
    install      Install Etcd to the system
    uninstall    Uninstall Etcd and keeping the data directory
    purge        Uninstall Etcd and remove the data directory

COPYRIGHT:
    Copyright (c) 2021 mritd, All rights reserved.
```

### 二、配置

默认情况下，**安装包会释放 `/etc/etcd` 目录，该目录存放一些样例配置:**

- etcd.cluster.yaml: 集群样例配置
- etcd.single.yaml: 单点样例配置
- etcd.yaml: 默认配置

可自行修改相关配置来选择启动单点模式与集群模式。
