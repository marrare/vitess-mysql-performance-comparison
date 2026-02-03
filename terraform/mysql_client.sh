#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/user-data-sysbench.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[user-data] Boot at $(date -Is)"

# ==========================
# Packages (Ubuntu ARM64)
# ==========================
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y \
  ca-certificates \
  curl \
  jq \
  unzip \
  netcat-openbsd \
  iproute2 \
  dnsutils \
  mysql-client \
  sysbench \
  sysstat \
  htop

# ==========================
# Env vars file
# ==========================
mkdir -p /etc/sysbench
chmod 700 /etc/sysbench

cat >/etc/sysbench/benchmark.env <<'EOF'
# --------------------------
# MySQL Standalone
# --------------------------
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3307
MYSQL_ROOT_PASSWORD=password
MYSQL_DATABASE=benchmark

# --------------------------
# Vitess (VTGate)
# --------------------------
VITESS_HOST=127.0.0.1
VITESS_PORT=15306
VITESS_USER=user
VITESS_PASSWORD=password
VITESS_DATABASE=benchmark
EOF

chmod 600 /etc/sysbench/benchmark.env

# ==========================
# Helper for interactive shell
# ==========================
cat >/etc/profile.d/benchmark_env.sh <<'EOF'
# Load benchmark env vars:
#   source /etc/sysbench/benchmark.env
EOF
chmod 644 /etc/profile.d/benchmark_env.sh

echo "[user-data] Wrote env file: /etc/sysbench/benchmark.env"
echo "[user-data] Usage:"
echo "  source /etc/sysbench/benchmark.env"
echo "  ENGINE=vitess SCALE=alta ./seu_script.sh"

echo "[user-data] Done at $(date -Is)"
