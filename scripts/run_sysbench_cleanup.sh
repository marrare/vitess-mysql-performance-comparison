!/bin/bash

# Vitess drop tables;
vtctldclient ApplySchema --ddl-strategy "vitess" --sql "DROP TABLE sbtest1;" benchmark; sleep 1;
vtctldclient ApplySchema --ddl-strategy "vitess" --sql "DROP TABLE sbtest2;" benchmark; sleep 1;
vtctldclient ApplySchema --ddl-strategy "vitess" --sql "DROP TABLE sbtest3;" benchmark; sleep 1;
vtctldclient ApplySchema --ddl-strategy "vitess" --sql "DROP TABLE sbtest4;" benchmark; sleep 1;
vtctldclient ApplySchema --ddl-strategy "vitess" --sql "DROP TABLE sbtest5;" benchmark; sleep 1;
vtctldclient ApplySchema --ddl-strategy "vitess" --sql "DROP TABLE sbtest6;" benchmark; sleep 1; 
vtctldclient ApplySchema --ddl-strategy "vitess" --sql "DROP TABLE sbtest7;" benchmark; sleep 1;
vtctldclient ApplySchema --ddl-strategy "vitess" --sql "DROP TABLE sbtest8;" benchmark; sleep 1;
vtctldclient ApplySchema --ddl-strategy "vitess" --sql "DROP TABLE sbtest9;" benchmark; sleep 1;
vtctldclient ApplySchema --ddl-strategy "vitess" --sql "DROP TABLE sbtest10;" benchmark; sleep 1;

# MySQL drop tables;
echo "set 'benchpass'"; docker exec -it mysql-benchmark mysql -u benchuser -P 3306 -h 127.0.0.1 -p benchmark -e "DROP DATABASE IF EXISTS benchmark; CREATE DATABASE benchmark;";