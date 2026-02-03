#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/sysbench.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[user-data] Boot at $(date -Is)"

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


wget https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/arm64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb

cat >/opt/aws/amazon-cloudwatch-agent/bin/config.json <<'EOF'
{
    "metrics": {
        "metrics_collected": {
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        },
        "append_dimensions": {
            "InstanceId": "${aws:InstanceId}"
        }
    }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s