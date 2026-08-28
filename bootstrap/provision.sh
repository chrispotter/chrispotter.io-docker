#!/usr/bin/env bash
# Provision a fresh Ubuntu 24.04 droplet as the chrispotter.io Compose host.
# Idempotent: safe to re-run.
#
#   curl -fsSL https://raw.githubusercontent.com/chrispotter/chrispotter.io-docker/main/bootstrap/provision.sh | sudo bash
# or copy/paste into the DigitalOcean web console as root.

set -euo pipefail

SWAP_SIZE_GB=2
SWAPFILE=/swapfile
DEPLOY_USER=deploy
DOCKER_NETWORK=edge

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }

[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo bash)."; exit 1; }

. /etc/os-release
log "Host: $PRETTY_NAME ($(uname -m)), $(nproc) vCPU, $(free -m | awk '/^Mem:/{print $2}') MB RAM"
case "${VERSION_ID:-}" in
  24.04|26.04) ;;   # noble / resolute -- both have docker-ce published upstream
  *) warn "Expected Ubuntu 24.04 or 26.04, found ${VERSION_ID:-unknown}. Continuing anyway." ;;
esac

# ---------------------------------------------------------------- swap
if swapon --show | grep -q .; then
  log "Swap already active, skipping"
else
  log "Creating ${SWAP_SIZE_GB}G swapfile"
  if ! fallocate -l "${SWAP_SIZE_GB}G" "$SWAPFILE" 2>/dev/null; then
    warn "fallocate unavailable or unsupported here; falling back to dd"
    dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((SWAP_SIZE_GB * 1024)) status=none
  fi
  chmod 600 "$SWAPFILE"
  mkswap "$SWAPFILE" >/dev/null
  swapon "$SWAPFILE"
  grep -q "^${SWAPFILE} " /etc/fstab || echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
fi

# Swap is insurance, not routine storage.
echo 'vm.swappiness=10' > /etc/sysctl.d/99-swappiness.conf
sysctl -q -w vm.swappiness=10

# ------------------------------------------------------------- packages
log "Updating base system"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq ca-certificates curl gnupg ufw unattended-upgrades

log "Enabling unattended security upgrades"
dpkg-reconfigure -f noninteractive unattended-upgrades

# --------------------------------------------------------------- docker
if command -v docker >/dev/null 2>&1; then
  log "Docker already installed, skipping repo setup"
else
  log "Installing Docker Engine from the official repository"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# Unbounded container logs will eat a 25 GB disk. Cap them before anything runs.
log "Capping container log growth"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
JSON
systemctl restart docker
systemctl enable --now docker >/dev/null

# The include: key needs Compose v2.20+.
COMPOSE_VER="$(docker compose version --short 2>/dev/null || echo 0)"
log "Docker $(docker --version | awk '{print $3}' | tr -d ,) / Compose ${COMPOSE_VER}"
case "$COMPOSE_VER" in
  0) warn "Compose plugin not detected — the unified compose layout needs v2.20+" ;;
  *) awk -v v="$COMPOSE_VER" 'BEGIN{split(v,a,".");
       if (a[1]<2 || (a[1]==2 && a[2]<20))
         print "[warn] Compose " v " is older than 2.20; include: will not work" }' ;;
esac

# -------------------------------------------------------------- network
if docker network inspect "$DOCKER_NETWORK" >/dev/null 2>&1; then
  log "Docker network '$DOCKER_NETWORK' already exists"
else
  log "Creating shared proxy network '$DOCKER_NETWORK'"
  docker network create "$DOCKER_NETWORK" >/dev/null
fi

# ----------------------------------------------------------- deploy user
if id "$DEPLOY_USER" >/dev/null 2>&1; then
  log "User '$DEPLOY_USER' already exists"
else
  log "Creating '$DEPLOY_USER' (docker group, no password login)"
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
  usermod -aG docker "$DEPLOY_USER"
  install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
  if [ -f /root/.ssh/authorized_keys ]; then
    install -m 600 -o "$DEPLOY_USER" -g "$DEPLOY_USER" \
      /root/.ssh/authorized_keys "/home/$DEPLOY_USER/.ssh/authorized_keys"
  else
    warn "No /root/.ssh/authorized_keys to copy — add a key for '$DEPLOY_USER' manually"
  fi
fi

install -d -o "$DEPLOY_USER" -g "$DEPLOY_USER" /srv/chrispotter

# ------------------------------------------------------------------ done
log "Provisioning complete"
free -h
echo
docker --version
docker compose version
echo
cat <<'NEXT'
Next, by hand:
  1. Tailscale:  curl -fsSL https://tailscale.com/install.sh | sh
                 tailscale up --ssh --hostname=chrispotter-web
  2. Confirm the DO Cloud Firewall allows 80 and 443 from anywhere,
     and 22 only from your address.
  3. Clone the repo into /srv/chrispotter as the deploy user.
NEXT
