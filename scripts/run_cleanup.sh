#!/usr/bin/env bash

export $(grep -v '^#' ../.env | xargs)

QUERY="use benchmark; TRUNCATE TABLE sbtest1; TRUNCATE TABLE sbtest2; TRUNCATE TABLE sbtest3; TRUNCATE TABLE sbtest4; TRUNCATE TABLE sbtest5; TRUNCATE TABLE sbtest6; TRUNCATE TABLE sbtest7; TRUNCATE TABLE sbtest8; TRUNCATE TABLE sbtest9; TRUNCATE TABLE sbtest10;"

case "$ENGINE" in
  vitess)
    mysql -u $VITESS_USER -P $VITESS_PORT -h $VITESS_HOST -p$VITESS_PASSWORD -e "$QUERY";                                  
    ;;
  mysql)
    if [ "$ENVIRONMENT" = "local" ]; then
      docker exec -it mysql-benchmark mysql -u root -p"$MYSQL_ROOT_PASSWORD" benchmark -e "$QUERY";
    else 
      mysql -h $MYSQL_HOST -u $MYSQL_USER -P $MYSQL_PORT -p"$MYSQL_ROOT_PASSWORD" benchmark -e "$QUERY";
    fi
    ;;
esac
