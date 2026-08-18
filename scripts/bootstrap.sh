#!/usr/bin/env bash

set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "error: run bootstrap as root"
    exit 1
fi

if [[ ! -f /etc/os-release ]]; then
    echo "error: cannot determine operating system"
    exit 1
fi

source /etc/os-release

if [[ "$ID" != "debian" || "$VERSION_ID" != "13" ]]; then
    echo "error: this bootstrap script targets Debian 13"
    echo "detected: ${PRETTY_NAME:-unknown}"
    exit 1
fi

DEPLOY_USER="${DEPLOY_USER:-deploy}"

echo "Updating Debian..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

echo "Installing base packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates \
    curl \
    git \
    gnupg \
    htop \
    jq \
    openssl \
    rclone \
    sudo \
    ufw \
    unattended-upgrades \
    vim

echo "Removing conflicting Docker packages..."
apt-get remove -y \
    docker.io \
    docker-compose \
    docker-doc \
    docker-buildx \
    podman-docker \
    containerd \
    runc \
    2>/dev/null || true

echo "Configuring Docker repository..."

install -m 0755 -d /etc/apt/keyrings

curl -fsSL \
    https://download.docker.com/linux/debian/gpg \
    -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

echo "Configuring Docker log rotation..."

mkdir -p /etc/docker

cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

systemctl enable docker
systemctl restart docker

echo "Creating deployment user..."

if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
    useradd \
        --create-home \
        --shell /bin/bash \
        "$DEPLOY_USER"
fi

usermod -aG docker,sudo "$DEPLOY_USER"

DEPLOY_HOME="$(getent passwd "$DEPLOY_USER" | cut -d: -f6)"

install \
    -d \
    -m 0700 \
    -o "$DEPLOY_USER" \
    -g "$DEPLOY_USER" \
    "$DEPLOY_HOME/.ssh"

SOURCE_USER="${SUDO_USER:-root}"
SOURCE_HOME="$(getent passwd "$SOURCE_USER" | cut -d: -f6)"
KEY_SOURCE="${SOURCE_HOME}/.ssh/authorized_keys"

if [[ ! -f "$KEY_SOURCE" && -f /root/.ssh/authorized_keys ]]; then
    KEY_SOURCE="/root/.ssh/authorized_keys"
fi

if [[ -f "$KEY_SOURCE" ]]; then
    install \
        -m 0600 \
        -o "$DEPLOY_USER" \
        -g "$DEPLOY_USER" \
        "$KEY_SOURCE" \
        "$DEPLOY_HOME/.ssh/authorized_keys"
else
    echo "WARNING: no authorized_keys file found."
    echo "Configure SSH access for '$DEPLOY_USER' before disabling initial SSH access."
fi

echo "Creating application directory..."

mkdir -p /opt/apps
chown "$DEPLOY_USER:$DEPLOY_USER" /opt/apps

echo "Configuring swap..."

if ! swapon --show --noheadings | grep -q .; then
    if [[ ! -f /swapfile ]]; then
        fallocate -l 4G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
    fi

    swapon /swapfile

    if ! grep -q '^/swapfile ' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
fi

cat > /etc/sysctl.d/99-vps-infra.conf <<'EOF'
vm.swappiness=10
EOF

sysctl --system >/dev/null

echo "Configuring firewall..."

ufw default deny incoming
ufw default allow outgoing

ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp

ufw --force enable

echo "Configuring unattended security updates..."

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

systemctl enable unattended-upgrades
systemctl restart unattended-upgrades

echo "Creating shared Docker networks..."

for network in vps-edge vps-data vps-monitoring; do
    docker network inspect "$network" >/dev/null 2>&1 \
        || docker network create "$network"
done

echo "Creating backup directory..."

mkdir -p /var/backups/vps-infra/postgres
chmod 700 /var/backups/vps-infra

if [[ -d /opt/vps-infra/systemd ]]; then
    echo "Installing infrastructure timers..."
    /opt/vps-infra/scripts/install-systemd.sh
else
    echo
    echo "NOTE: /opt/vps-infra was not detected."
    echo "Run 'make install-timers' after the repository is installed there."
fi

echo
echo "Bootstrap complete."
echo
echo "Docker:"
docker --version
docker compose version
echo
echo "Shared networks:"
docker network ls \
    --filter name=vps-
echo
echo "Next:"
echo "  1. Configure /opt/vps-infra/.env"
echo "  2. cd /opt/vps-infra"
echo "  3. make deploy"
echo "  4. make health"