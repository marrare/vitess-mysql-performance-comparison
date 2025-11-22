#!/usr/bin/env bash
set -e

ENGINE=$1          # mysql ou vitess
SCALE=$2           # baixa, media, alta

case "$ENGINE" in
  mysql)
    DB=$MYSQL_DB
    HOST=$MYSQL_HOST
    PASSWORD=$MYSQL_PASSWORD
    PORT=$MYSQL_PORT
    USER=$MYSQL_USER
    ;;
  vitess)
    DB=$VITESS_DB
    HOST=$VITESS_HOST
    PASSWORD=$VITESS_PASSWORD
    PORT=$VITESS_PORT
    USER=$VITESS_USER
    ;;
esac

BENCHMARK_RESULTS=/home/marciliosantos/tcc/vitess-mysql-performance-comparison/benchbase/results

OUT_DIR="${BENCHMARK_RESULTS}/local/${ENGINE}/${SCALE}"
mkdir -p "$OUT_DIR"

BENCHBASE_JAR=/home/marciliosantos/tcc/vitess-mysql-performance-comparison/benchbase/benchbase-mysql/benchbase.jar
BENCHBASE_CONFIG_XML=/home/marciliosantos/tcc/vitess-mysql-performance-comparison/benchbase/config/tpcc_${ENGINE}_${SCALE}.xml

java -jar $BENCHBASE_JAR \
  -b tpcc \
  -c $BENCHBASE_CONFIG_XML \
  --create=true \
  --load=true \
  --execute=true \
  -d $OUT_DIR