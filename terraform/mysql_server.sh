#!/bin/bash

yum update -y
yum install -y mariadb-server amazon-cloudwatch-agent

systemctl start mariadb
systemctl enable mariadb

mkdir -p /etc/mysql

cat > /etc/mysql/init.sql <<EOF
CREATE USER 'userbench'@'%' IDENTIFIED BY 'password';
CREATE USER 'userbench'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON *.* TO 'userbench'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'userbench'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
CREATE DATABASE benchmark;
EOF

mysql -u root -p password mysql < /etc/mysql/init.sql

mkdir -p /etc/my.cnf.d

cat > /etc/my.cnf.d/custom.cnf <<EOF
[mysqld]
max_connections = 500
max_prepared_stmt_count = 100000
port = 3306
bind-address = 0.0.0.0
EOF

systemctl restart mariadb

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