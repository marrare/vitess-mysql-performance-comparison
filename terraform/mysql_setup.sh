#!/bin/bash

# Atualiza o sistema
yum update -y

# Instala o MariaDB (substituto comum do MySQL no Amazon Linux)
yum install -y mariadb-server

# Inicia e habilita o serviço
systemctl start mariadb
systemctl enable mariadb

# Configuração de segurança automatizada (equivalente ao mysql_secure_installation)
mysql -e "UPDATE mysql.user SET Password = PASSWORD('password') WHERE User = 'root';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"

# Cria diretório de config personalizada se não existir
mkdir -p /etc/my.cnf.d

# Adiciona configuração personalizada
cat > /etc/my.cnf.d/custom.cnf <<EOF
[mysqld]
port = 3654
bind-address = 0.0.0.0
EOF

# Reinicia o serviço para aplicar as mudanças
systemctl restart mariadb

# Opcional: libera a porta no firewall local (se estiver usando firewalld — raro no Amazon Linux)
# Se estiver usando security groups (recomendado na AWS), isso não é necessário.