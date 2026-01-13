# etcd-pack Refactor Design

## Overview

Refactor the etcd packaging project from makeself + shell scripts to a modern nFPM + Taskfile based solution, supporting native deb/rpm/apk package generation.

## Goals

- Replace makeself with nFPM for native package generation
- Replace Makefile + build.sh with Taskfile
- Support multiple architectures (default: amd64 + arm64, configurable)
- Support multiple package formats (deb priority, rpm/apk optional)
- Modernize CI with GitHub Actions and GitLab CI support

## Project Structure

```
etcd-pack/
├── Taskfile.yml              # Main build configuration
├── nfpm.yaml                 # nFPM packaging config (template)
├── .env                      # Default config (version, architectures)
├── configs/
│   ├── etcd.yaml             # Default config (single node, ready to start)
│   └── etcd.cluster.yaml     # Cluster template (3 nodes with TLS)
├── scripts/
│   ├── postinstall.sh        # Create user, setup directories, enable service
│   ├── preremove.sh          # Stop and disable service
│   └── postremove.sh         # Cleanup (supports purge for deb/rpm/apk)
├── dist/                     # Build artifacts (gitignored)
│   ├── bin/                  # Downloaded etcd binaries
│   ├── systemd/              # Downloaded etcd.service from upstream
│   └── packages/             # Generated deb/rpm/apk packages
├── .github/
│   └── workflows/
│       └── release.yml       # GitHub Actions workflow
├── .gitlab-ci.yml            # GitLab CI configuration
├── .gitignore
└── README.md
```

## Components

### 1. Taskfile.yml

```yaml
version: '3'

vars:
  VERSION:
    sh: curl -fsSL https://api.github.com/repos/etcd-io/etcd/releases/latest | jq -r '.tag_name | ltrimstr("v")'
  ARCHS: '{{.ARCHS | default "amd64 arm64"}}'
  DIST_DIR: './dist'
  ETCD_DOWNLOAD_URL: 'https://github.com/etcd-io/etcd/releases/download'
  ETCD_RAW_URL: 'https://raw.githubusercontent.com/etcd-io/etcd'

tasks:
  default:
    desc: Show available tasks
    cmds: [task --list]

  download:
    desc: Download etcd binaries and systemd service file
    cmds:
      - for: { var: ARCHS }
        cmd: # Download and extract etcd-v{{.VERSION}}-linux-{{.ITEM}}.tar.gz
      - # Download etcd.service from official repo

  build:
    desc: Build deb packages for all architectures
    deps: [download]
    cmds:
      - for: { var: ARCHS }
        cmd: nfpm package -p deb -f nfpm.yaml --target {{.DIST_DIR}}/packages/

  build:rpm:
    desc: Build rpm packages for all architectures
    deps: [download]
    cmds:
      - for: { var: ARCHS }
        cmd: nfpm package -p rpm -f nfpm.yaml --target {{.DIST_DIR}}/packages/

  release:
    desc: Create GitHub release using gh CLI
    cmds:
      - gh release create v{{.VERSION}} {{.DIST_DIR}}/packages/* --title "etcd {{.VERSION}}"

  clean:
    desc: Remove build artifacts
    cmds:
      - rm -rf {{.DIST_DIR}}

  check:upstream:
    desc: Check latest etcd version from upstream
    cmds:
      - curl -fsSL https://api.github.com/repos/etcd-io/etcd/releases/latest | jq -r '.tag_name'
```

### 2. nfpm.yaml

```yaml
name: etcd
arch: ${ARCH}
version: ${VERSION}
release: 1
maintainer: kovacs
description: Highly-available key value store for shared configuration and service discovery
vendor: etcd-io
homepage: https://etcd.io
license: Apache-2.0

contents:
  # Binaries
  - src: ./dist/bin/${ARCH}/etcd
    dst: /usr/bin/etcd
    file_info:
      mode: 0755

  - src: ./dist/bin/${ARCH}/etcdctl
    dst: /usr/bin/etcdctl
    file_info:
      mode: 0755

  - src: ./dist/bin/${ARCH}/etcdutl
    dst: /usr/bin/etcdutl
    file_info:
      mode: 0755

  # Systemd service
  - src: ./dist/systemd/etcd.service
    dst: /lib/systemd/system/etcd.service
    file_info:
      mode: 0644

  # Config files (marked as config to preserve user changes on upgrade)
  - src: ./configs/etcd.yaml
    dst: /etc/etcd/etcd.yaml
    type: config|noreplace
    file_info:
      mode: 0644

  - src: ./configs/etcd.cluster.yaml
    dst: /etc/etcd/etcd.cluster.yaml
    type: config|noreplace
    file_info:
      mode: 0644

  # Empty directories
  - dst: /var/lib/etcd
    type: dir
    file_info:
      mode: 0755
      owner: etcd
      group: etcd

scripts:
  postinstall: ./scripts/postinstall.sh
  preremove: ./scripts/preremove.sh
  postremove: ./scripts/postremove.sh
```

### 3. scripts/postinstall.sh

```bash
#!/bin/bash
set -e

# Create etcd system user if not exists
if ! id -u etcd >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin etcd
fi

# Ensure data directory ownership
chown -R etcd:etcd /var/lib/etcd

# Reload systemd to recognize new service
systemctl daemon-reload

# Enable service but don't start (let user configure first)
systemctl enable etcd.service

echo "etcd installed successfully."
echo "  - Edit config: /etc/etcd/etcd.yaml"
echo "  - Start service: systemctl start etcd"
```

### 4. scripts/preremove.sh

```bash
#!/bin/bash
set -e

# Stop service if running
if systemctl is-active --quiet etcd.service; then
    systemctl stop etcd.service
fi

# Disable service
systemctl disable etcd.service || true
```

### 5. scripts/postremove.sh

```bash
#!/bin/bash
set -e

# Detect package manager and removal type
# - deb: $1 = remove|purge|upgrade|...
# - rpm: $1 = 0 (uninstall) | 1 (upgrade)
# - apk: no args, check APK_PURGE env var for purge behavior

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
    # Remove etcd user
    if id -u etcd >/dev/null 2>&1; then
        userdel etcd || true
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
```

### 6. configs/etcd.yaml

```yaml
# Default etcd configuration - single node, ready to start
name: 'default'
data-dir: '/var/lib/etcd'

listen-client-urls: 'http://127.0.0.1:2379'
advertise-client-urls: 'http://127.0.0.1:2379'

listen-peer-urls: 'http://127.0.0.1:2380'
initial-advertise-peer-urls: 'http://127.0.0.1:2380'

initial-cluster: 'default=http://127.0.0.1:2380'
initial-cluster-token: 'etcd-cluster'
initial-cluster-state: 'new'

# Logging
log-level: 'info'

# Auto compaction
auto-compaction-mode: 'periodic'
auto-compaction-retention: '1h'
```

### 7. configs/etcd.cluster.yaml

```yaml
# Cluster configuration template
# Copy to /etc/etcd/etcd.yaml and modify for each node

name: 'etcd1'  # Change: etcd1, etcd2, etcd3
data-dir: '/var/lib/etcd'

listen-client-urls: 'https://0.0.0.0:2379'
advertise-client-urls: 'https://10.0.0.11:2379'  # Change: node IP

listen-peer-urls: 'https://0.0.0.0:2380'
initial-advertise-peer-urls: 'https://10.0.0.11:2380'  # Change: node IP

initial-cluster: 'etcd1=https://10.0.0.11:2380,etcd2=https://10.0.0.12:2380,etcd3=https://10.0.0.13:2380'
initial-cluster-token: 'etcd-cluster'
initial-cluster-state: 'new'

# TLS - client
client-transport-security:
  cert-file: '/etc/etcd/ssl/etcd.crt'
  key-file: '/etc/etcd/ssl/etcd.key'
  trusted-ca-file: '/etc/etcd/ssl/ca.crt'
  client-cert-auth: true

# TLS - peer
peer-transport-security:
  cert-file: '/etc/etcd/ssl/etcd.crt'
  key-file: '/etc/etcd/ssl/etcd.key'
  trusted-ca-file: '/etc/etcd/ssl/ca.crt'
  client-cert-auth: true

# Logging
log-level: 'info'

# Auto compaction
auto-compaction-mode: 'revision'
auto-compaction-retention: '1000'

# Quotas
quota-backend-bytes: 8589934592  # 8GB
```

### 8. .github/workflows/release.yml

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      version:
        description: 'etcd version to package'
        required: false

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        arch: [amd64, arm64]
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y jq
          # Install task
          sh -c "$(curl -fsSL https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin
          # Install nfpm
          echo 'deb [trusted=yes] https://repo.goreleaser.com/apt/ /' | sudo tee /etc/apt/sources.list.d/goreleaser.list
          sudo apt-get update
          sudo apt-get install -y nfpm

      - name: Build packages
        run: task build ARCHS=${{ matrix.arch }}
        env:
          VERSION: ${{ inputs.version || github.ref_name }}

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: packages-${{ matrix.arch }}
          path: dist/packages/*

  release:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          path: packages
          merge-multiple: true

      - name: Create release
        uses: softprops/action-gh-release@v2
        with:
          files: packages/*
```

### 9. .gitlab-ci.yml

```yaml
stages:
  - build
  - release

variables:
  VERSION: ""

.build:
  stage: build
  image: ubuntu:24.04
  before_script:
    - apt-get update && apt-get install -y curl jq
    - sh -c "$(curl -fsSL https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin
    - curl -fsSL https://repo.goreleaser.com/apt/gpg.key | gpg --dearmor -o /usr/share/keyrings/goreleaser.gpg
    - echo "deb [signed-by=/usr/share/keyrings/goreleaser.gpg] https://repo.goreleaser.com/apt/ /" > /etc/apt/sources.list.d/goreleaser.list
    - apt-get update && apt-get install -y nfpm
  artifacts:
    paths:
      - dist/packages/*

build:amd64:
  extends: .build
  script:
    - task build ARCHS=amd64

build:arm64:
  extends: .build
  script:
    - task build ARCHS=arm64

release:
  stage: release
  image: registry.gitlab.com/gitlab-org/release-cli:latest
  needs:
    - build:amd64
    - build:arm64
  script:
    - echo "Creating release for $CI_COMMIT_TAG"
  release:
    tag_name: $CI_COMMIT_TAG
    name: "etcd $CI_COMMIT_TAG"
    description: "etcd packages for $CI_COMMIT_TAG"
    assets:
      links:
        - name: "etcd-${CI_COMMIT_TAG}-amd64.deb"
          url: "${CI_PROJECT_URL}/-/jobs/${CI_JOB_ID}/artifacts/file/dist/packages/etcd_${CI_COMMIT_TAG}_amd64.deb"
        - name: "etcd-${CI_COMMIT_TAG}-arm64.deb"
          url: "${CI_PROJECT_URL}/-/jobs/${CI_JOB_ID}/artifacts/file/dist/packages/etcd_${CI_COMMIT_TAG}_arm64.deb"
  rules:
    - if: $CI_COMMIT_TAG
```

### 10. .gitignore

```gitignore
# Build artifacts
dist/

# Packages
*.deb
*.rpm
*.apk

# Editor
.idea/
.vscode/
*.swp
*~

# OS
.DS_Store
Thumbs.db
```

### 11. README.md

```markdown
# etcd-pack

Package etcd into deb/rpm using nFPM.

## Requirements

- curl
- jq
- [task](https://taskfile.dev)
- [nfpm](https://nfpm.goreleaser.com)

### Install dependencies (Debian/Ubuntu)

\`\`\`bash
# task
sh -c "$(curl -fsSL https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin

# nfpm
echo 'deb [trusted=yes] https://repo.goreleaser.com/apt/ /' | sudo tee /etc/apt/sources.list.d/goreleaser.list
sudo apt-get update && sudo apt-get install -y nfpm
\`\`\`

## Usage

\`\`\`bash
# Build deb packages (latest etcd, amd64 + arm64)
task build

# Build specific version
task build VERSION=3.5.16

# Build single architecture
task build ARCHS=amd64

# Build rpm packages
task build:rpm

# Check upstream latest version
task check:upstream

# Create GitHub release
task release

# Clean build artifacts
task clean
\`\`\`

## Install etcd

\`\`\`bash
# Install
sudo apt install ./etcd_3.6.7_amd64.deb

# Remove (keep config and data)
sudo apt remove etcd

# Purge (remove everything)
sudo apt purge etcd
\`\`\`

## Configuration

- Default config: `/etc/etcd/etcd.yaml`
- Cluster template: `/etc/etcd/etcd.cluster.yaml`
- Data directory: `/var/lib/etcd/`
- TLS certificates: `/etc/etcd/ssl/`

## License

Apache-2.0
```

## Implementation Steps

1. Delete old files: `build.sh`, `Makefile`, `version`, `pack/`
2. Create new directory structure
3. Write `Taskfile.yml`
4. Write `nfpm.yaml`
5. Write scripts (`postinstall.sh`, `preremove.sh`, `postremove.sh`)
6. Write configs (`etcd.yaml`, `etcd.cluster.yaml`)
7. Write CI configs (`.github/workflows/release.yml`, `.gitlab-ci.yml`)
8. Update `.gitignore`
9. Update `README.md`
10. Test build locally: `task build`
11. Test package installation in VM/container

## Dependencies

- curl: HTTP client
- jq: JSON processor
- task: Task runner (https://taskfile.dev)
- nfpm: Package builder (https://nfpm.goreleaser.com)
