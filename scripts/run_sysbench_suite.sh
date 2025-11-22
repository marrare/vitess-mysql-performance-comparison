# local/scripts/run_sysbench_suite.sh
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

case "$SCALE" in
  baixa) TABLE_SIZE=100000 ;;
  media) TABLE_SIZE=1000000 ;;
  alta)  TABLE_SIZE=10000000 ;;
esac

OUT_DIR="${BENCHMARK_RESULTS}/local/${ENGINE}/${SCALE}"
mkdir -p "$OUT_DIR"

# prepare (cria e popula as tabelas)
sysbench oltp_read_write \
  --mysql-db=$DB \
  --mysql-host=$HOST \
  --mysql-password=$PASSWORD \
  --mysql-port=$PORT \
  --mysql-user=$USER \
  --tables=10 \
  --table-size=$TABLE_SIZE \
  prepare

# read
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
  run > "$OUT_DIR/read.txt"

# write
sysbench oltp_write_only \
  --mysql-db=$DB \
  --mysql-host=$HOST \
  --mysql-password=$PASSWORD \
  --mysql-port=$PORT \
  --mysql-user=$USER \
  --tables=10 \
  --table-size=$TABLE_SIZE \
  --threads=50 \
  --time=60 \
  run > "$OUT_DIR/write.txt"

# update
sysbench oltp_update_index \
  --mysql-db=$DB \
  --mysql-host=$HOST \
  --mysql-password=$PASSWORD \
  --mysql-port=$PORT \
  --mysql-user=$USER \
  --tables=10 \
  --table-size=$TABLE_SIZE \
  --threads=50 \
  --time=60 \
  run > "$OUT_DIR/update.txt"

# complex (read+write)
sysbench oltp_read_write \
  --mysql-db=$DB \
  --mysql-host=$HOST \
  --mysql-password=$PASSWORD \
  --mysql-port=$PORT \
  --mysql-user=$USER \
  --tables=10 \
  --table-size=$TABLE_SIZE \
  --threads=50 \
  --time=60 \
  run > "$OUT_DIR/complex.txt"

# delete
sysbench oltp_delete \
  --mysql-db=$DB \
  --mysql-host=$HOST \
  --mysql-password=$PASSWORD \
  --mysql-port=$PORT \
  --mysql-user=$USER \
  --tables=10 \
  --table-size=$TABLE_SIZE \
  --threads=50 \
  --time=60 \
  run > "$OUT_DIR/delete.txt"

# cleanup (drop tables)
sysbench oltp_read_write \
  --mysql-db=$DB \
  --mysql-host=$HOST \
  --mysql-password=$PASSWORD \
  --mysql-port=$PORT \
  --mysql-user=$USER \
  --tables=10 \
  --table-size=$TABLE_SIZE \
  cleanup >/dev/null 2>&1