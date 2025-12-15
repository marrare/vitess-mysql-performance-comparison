#!/usr/bin/env bash

export $(grep -v '^#' ../.env | xargs)

case "$ENGINE" in
  vitess)
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
    ;;
  mysql)
    if [ "$ENVIRONMENT" = "local" ]; then
      docker exec -it mysql-benchmark mysql -u root -P $MYSQL_PORT -h $MYSQL_HOST -p benchmark -e "DROP DATABASE IF EXISTS benchmark; CREATE DATABASE benchmark;";
    else 
      mysql -u root -P $MYSQL_PORT -h $MYSQL_HOST -p$MYSQL_ROOT_PASSWORD -e "DROP DATABASE IF EXISTS benchmark; CREATE DATABASE benchmark;";
    fi
    ;;
esac

# Vitess drop tables;

# MySQL drop tables;