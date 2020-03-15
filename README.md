## etcd-deb

> 本仓库为 etcd 二进制文件生成 deb 包，方便在宿主机安装以及配置。

### 一、使用

可直接从 [release](https://github.com/mritd/etcd-deb/releases) 页面下载对应版本的 deb 包并安装；注意**本仓库 deb 包与官方 apt 源内的 etcd deb 包冲突，请勿同时安装两个 etcd。**

- etcd_*_amd64.deb: etcd 主程序安装包，包含必要二进制及配置文件和辅助脚本
- cfssl_*_amd64.deb: cloudflare/cfssl 二进制安装包，包含自行 build 的 cfssl，用于为 etcd 签署证书使用

### 二、配置

默认情况下，安装完成后会在 `/etc/etcd` 目录下找到相关配置样例:

- etcd.cluster.conf: 集群模式配置样例
- etcd.single.conf: 单机模式配置样例
- etcd.conf: 默认配置(默认集群模式，与 etcd.cluster.conf 相同)

针对集群模式直接修改默认配置的 `ETCD_NAME` 和相关 IP 配置以及 `ETCD_INITIAL_CLUSTER_TOKEN` 既可启动；
默认配置已经可以满足一些常规使用，如果需要更细节调优请自行阅读官方文档增加或修改特定参数。

- create.sh: cfssl 创建证书脚本
- etcd-csr.json: cfssl 证书 csr 配置
- etcd-gencert.json: cfssl 证书生成配置
- etcd-root-ca-csr.json: cfssl 生成 etcd CA 配置

**用户需要安装 cfssl 并自行修改 `etcd-csr.json` 配置内相关 IP 来为 etcd 签署 TLS 证书；** TLS 证书以及
CA 证书默认有效期为 10 年，可通过修改 `etcd-gencert.json` 和 `etcd-root-ca-csr.json` 进行配置；证书生成
完成后请自行移动到 `/etc/etcd/ssl` 目录，然后修复证书权限 `chown -R etcd:etcd /etc/etcd/ssl` 确保 etcd
能正确读取；高级用户可自行安放证书位置以及调整证书目录，甚至不采用 cfssl 而通过其他工具如 openssl 生成证书。

### 三、编译

如果想要特定版本而 release 页没有提供，则可以通过本仓库自行 build；build 所需环境如下:

- OS: Ubuntu 18.04
- Golang: 1.13+
- Docker: Installed
- Docker Image: mritd/fpm
- Build Tool: make、fakeroot

针对 etcd-deb 的 build 无需 Golang 环境和 fakerroot；其他环境准备好后 clone 本仓库源码修改 `version` 文件内版本号
然后执行 `make` 既可，编译过程会下载 etcd 指定版本的官方预编译二进制，然后通过 fpm 工具进行打包；如果需要编译 cfssl，
请自行 clone [cloudflare/cfssl](https://github.com/cloudflare/cfssl) 仓库源码，然后执行 `make package-deb` 既可，
cfssl 编译需要 fakeroot 以及 Golang 环境。

### 四、为何不使用 fpm 官方镜像

[mritd/fpm](https://github.com/mritd/dockerfile/blob/master/fpm/Dockerfile) 一般都使用 fpm master 源码构建完成，官方 fpm 一般为 release 版本，目前 fpm 官方最后一个
release 对 systemd 支持还不够完善，但是相关功能 master 已经有了，所以需要使用自己编译的 fpm 镜像。
