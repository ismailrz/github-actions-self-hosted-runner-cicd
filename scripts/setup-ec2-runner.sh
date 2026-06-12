#!/usr/bin/env bash
# setup-ec2-runner.sh
#
# Run this on your EC2 instance to install and register a GitHub Actions
# self-hosted runner.
#
# Usage:
#   chmod +x setup-ec2-runner.sh
#   ./setup-ec2-runner.sh \
#     --repo    https://github.com/YOUR_ORG/YOUR_REPO \
#     --token   YOUR_REGISTRATION_TOKEN \
#     --name    my-ec2-runner \
#     --labels  self-hosted,linux,x64,ec2
#
# Get your registration token at:
#   GitHub repo → Settings → Actions → Runners → New self-hosted runner

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
RUNNER_VERSION="2.317.0"
RUNNER_USER="github-runner"
RUNNER_DIR="/opt/github-runner"
RUNNER_NAME="ec2-runner-$(hostname -s)"
RUNNER_LABELS="self-hosted,linux,x64,ec2"
REPO_URL=""
REG_TOKEN=""

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --repo)   REPO_URL="$2";  shift 2 ;;
    --token)  REG_TOKEN="$2"; shift 2 ;;
    --name)   RUNNER_NAME="$2"; shift 2 ;;
    --labels) RUNNER_LABELS="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

[[ -z "$REPO_URL"  ]] && { echo "ERROR: --repo is required";  exit 1; }
[[ -z "$REG_TOKEN" ]] && { echo "ERROR: --token is required"; exit 1; }

echo "=== GitHub Actions Self-Hosted Runner Setup ==="
echo "Repo:    $REPO_URL"
echo "Name:    $RUNNER_NAME"
echo "Labels:  $RUNNER_LABELS"
echo "Dir:     $RUNNER_DIR"
echo ""

# ── 1. Install system dependencies ───────────────────────────────────────────
echo "[1/6] Installing system dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
  curl jq git tar gzip \
  apt-transport-https ca-certificates gnupg lsb-release

# Docker
if ! command -v docker &>/dev/null; then
  echo "  Installing Docker..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) \
    signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io
  sudo systemctl enable --now docker
fi

# AWS CLI v2
if ! command -v aws &>/dev/null; then
  echo "  Installing AWS CLI..."
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp/
  sudo /tmp/aws/install
  rm -rf /tmp/awscliv2.zip /tmp/aws
fi

# Node.js (via nvm so the runner can use actions/setup-node)
if ! command -v node &>/dev/null; then
  echo "  Installing nvm + Node.js..."
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

# ── 2. Create dedicated runner user ──────────────────────────────────────────
echo "[2/6] Creating runner user '$RUNNER_USER'..."
if ! id "$RUNNER_USER" &>/dev/null; then
  sudo useradd -m -s /bin/bash "$RUNNER_USER"
fi
sudo usermod -aG docker "$RUNNER_USER"   # allow Docker without sudo

# ── 3. Download runner package ───────────────────────────────────────────────
echo "[3/6] Downloading runner v${RUNNER_VERSION}..."
ARCH=$(dpkg --print-architecture | sed 's/amd64/x64/' | sed 's/aarch64/arm64/')
RUNNER_TAR="actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_TAR}"

sudo mkdir -p "$RUNNER_DIR"
sudo chown "$RUNNER_USER":"$RUNNER_USER" "$RUNNER_DIR"

sudo -u "$RUNNER_USER" bash -c "
  cd '$RUNNER_DIR'
  curl -fsSL '$RUNNER_URL' -o runner.tar.gz
  tar xzf runner.tar.gz
  rm runner.tar.gz
"

# ── 4. Configure runner ───────────────────────────────────────────────────────
echo "[4/6] Configuring runner..."
sudo -u "$RUNNER_USER" bash -c "
  cd '$RUNNER_DIR'
  ./config.sh \
    --url '$REPO_URL' \
    --token '$REG_TOKEN' \
    --name '$RUNNER_NAME' \
    --labels '$RUNNER_LABELS' \
    --work '_work' \
    --unattended \
    --replace
"

# ── 5. Install as a systemd service ──────────────────────────────────────────
echo "[5/6] Installing runner as systemd service..."
sudo bash -c "cd '$RUNNER_DIR' && ./svc.sh install $RUNNER_USER"
sudo bash -c "cd '$RUNNER_DIR' && ./svc.sh start"

# ── 6. Verify ────────────────────────────────────────────────────────────────
echo "[6/6] Verifying runner service..."
SERVICE_NAME="actions.runner.$(basename $REPO_URL).${RUNNER_NAME}.service"
sleep 2
sudo systemctl status "$SERVICE_NAME" --no-pager || true

echo ""
echo "=== Setup Complete ==="
echo "Runner '$RUNNER_NAME' is registered and running."
echo ""
echo "Useful commands:"
echo "  sudo systemctl status  $SERVICE_NAME"
echo "  sudo systemctl restart $SERVICE_NAME"
echo "  sudo journalctl -u     $SERVICE_NAME -f"
echo ""
echo "To remove this runner later:"
echo "  cd $RUNNER_DIR"
echo "  sudo ./svc.sh stop && sudo ./svc.sh uninstall"
echo "  ./config.sh remove --token <REMOVE_TOKEN>"
