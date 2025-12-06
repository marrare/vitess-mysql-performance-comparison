#!/usr/bin/env bash
set -e
export $(grep -v '^#' ../.env | xargs)
echo $MYSQL_USER

ENGINE=$1          # mysql ou vitess
SCALE=$2           # baixa, media, alta
ENVIRONMENT=$3     # local ou aws
PARALLEL=10

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

BENCHMARK_RESULTS=../sysbench/results
OUT_DIR="${BENCHMARK_RESULTS}/${ENVIRONMENT}/${ENGINE}/${SCALE}"
mkdir -p "$OUT_DIR"

# prepare (cria e popula as tabelas)
echo "Preparando o banco de dados..."
sysbench oltp_read_write \
  --mysql-db=$DB \
  --mysql-host=$HOST \
  --mysql-password=$PASSWORD \
  --mysql-port=$PORT \
  --mysql-user=$USER \
  --tables=10 \
  --table-size=$TABLE_SIZE \
  prepare

for i in $(seq 1 $PARALLEL); do
    echo "Iniciando sysbench $i..."
    sysbench oltp_read_only \
  --mysql-db=$DB \
  --mysql-host=$HOST \
  --mysql-password=$PASSWORD \
  --mysql-port=$PORT \
  --mysql-user=$USER \
  --tables=10 \
  --table-size=$TABLE_SIZE \
  --threads=50 \
  --time=60 \
  run > "$OUT_DIR/read_$1.log" &
done

wait
echo "Todos os sysbench finalizaram."