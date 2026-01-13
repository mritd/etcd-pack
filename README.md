# etcd-pack

Package etcd into deb/rpm using nFPM.

## Requirements

- curl
- jq
- [task](https://taskfile.dev)
- [nfpm](https://nfpm.goreleaser.com)

### Install dependencies (Debian/Ubuntu)

```bash
# task
sh -c "$(curl -fsSL https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin

# nfpm
echo 'deb [trusted=yes] https://repo.goreleaser.com/apt/ /' | sudo tee /etc/apt/sources.list.d/goreleaser.list
sudo apt-get update && sudo apt-get install -y nfpm
```

## Usage

```bash
# Build deb packages (latest etcd, amd64 + arm64)
task build

# Build specific version
task build VERSION=3.5.16

# Build single architecture
task build ARCHS=amd64

# Build rpm packages
task build:rpm

# Build apk packages
task build:apk

# Build all formats
task build:all

# Check upstream latest version
task check:upstream

# Create GitHub release
task release

# Clean build artifacts
task clean
```

## Install etcd

```bash
# Install
sudo apt install ./etcd_3.6.7_amd64.deb

# Remove (keep config and data)
sudo apt remove etcd

# Purge (remove everything)
sudo apt purge etcd
```

### RPM/APK purge

```bash
# rpm
ETCD_PURGE=1 rpm -e etcd

# apk
ETCD_PURGE=1 apk del etcd
```

## Configuration

- Default config: `/etc/etcd/etcd.yaml`
- Cluster template: `/etc/etcd/etcd.cluster.yaml`
- Data directory: `/var/lib/etcd/`
- TLS certificates: `/etc/etcd/ssl/`

## License

Apache-2.0
