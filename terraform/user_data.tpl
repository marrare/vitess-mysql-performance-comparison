#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/sysbench.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[user-data] Boot at $(date -Is)"

# ==========================
# Packages (Ubuntu ARM64)
# ==========================
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y \
  automake \
  ca-certificates \
  curl \
  dnsutils \
  gcc \
  git \
  htop \
  iproute2 \
  jq \
  libtool \
  make \
  mysql-client \
  netcat-openbsd \
  openssl \
  pkg-config \
  sysstat \
  unzip \
  libmysqlclient-dev

export LDFLAGS=-L/usr/local/opt/openssl/lib 

git clone https://github.com/akopytov/sysbench.git

cd sysbench
./autogen.sh
./configure --with-mysql
make -j
make install

# ==========================
# Env vars file
# ==========================
mkdir -p /etc/sysbench
chmod 700 /etc/sysbench

# Helper env file for benchmarks
cat >/etc/sysbench/benchmark.env <<EOF
# --------------------------
# MySQL Standalone
# --------------------------
MYSQL_HOST=${mysql_host}
MYSQL_PORT=3306
MYSQL_USER=userbench
MYSQL_PASSWORD=password
MYSQL_DATABASE=benchmark
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
echo "  ENGINE=vitess SCALE=alta ./run_parallel.sh | ./run_sequencial.sh"

echo "[user-data] Done at $(date -Is)"