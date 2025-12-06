#!/usr/bin/env bash
set -e
export $(grep -v '^#' ../.env | xargs)
echo $MYSQL_USER

ENGINE=$1          # mysql ou vitess
SCALE=$2           # baixa, media, alta
ENVIRONMENT=$3     # local ou aws
PARALLEL=2

case "$ENGINE" in
  mysql)
    DB=$MYSQL_DATABASE
    HOST=$MYSQL_HOST
    PASSWORD=$MYSQL_ROOT_PASSWORD
    PORT=$MYSQL_PORT
    USER='root'
    ;;
  vitess)
    DB=$VITESS_DATABASE
    HOST=$VITESS_HOST
    PASSWORD=$VITESS_PASSWORD
    PORT=$VITESS_PORT
    USER=$VITESS_USER
    ;;
esac

case "$SCALE" in
  baixa) TABLE_SIZE=10000 ;;
  media) TABLE_SIZE=100000 ;;
  alta)  TABLE_SIZE=1000000 ;;
esac

BENCHMARK_RESULTS=../sysbench/results
OUT_DIR="${BENCHMARK_RESULTS}/${ENVIRONMENT}/${ENGINE}/${SCALE}/parallel"
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
wait
echo "Banco de dados preparado."

# read
for i in $(seq 1 $PARALLEL); do
    echo "$(date +"%Y-%m-%d %H:%M:%S"): Iniciando teste read_$i"
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
  run > "$OUT_DIR/read_$i.txt" 2>&1 && echo "$(date +"%Y-%m-%d %H:%M:%S"): Teste read_$i finalizado" &
done
wait

# write
for i in $(seq 1 $PARALLEL); do
    echo "$(date +"%Y-%m-%d %H:%M:%S"): Iniciando teste write_$i"
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
  run > "$OUT_DIR/write_$i.txt" 2>&1 && echo "$(date +"%Y-%m-%d %H:%M:%S"): Teste write_$i finalizado" &
done
wait

# update
for i in $(seq 1 $PARALLEL); do
    echo "$(date +"%Y-%m-%d %H:%M:%S"): Iniciando teste update_$i"
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
  run > "$OUT_DIR/update_$i.txt" 2>&1 && echo "$(date +"%Y-%m-%d %H:%M:%S"): Teste update_$i finalizado" &
done
wait

# delete
for i in $(seq 1 $PARALLEL); do
    echo "$(date +"%Y-%m-%d %H:%M:%S"): Iniciando teste delete_$i"
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
  run > "$OUT_DIR/delete_$i.txt" 2>&1 && echo "$(date +"%Y-%m-%d %H:%M:%S"): Teste delete_$i finalizado" &
done
wait

# complex (read+write)
for i in $(seq 1 $PARALLEL); do
    echo "$(date +"%Y-%m-%d %H:%M:%S"): Iniciando teste complex_$i"
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
  run > "$OUT_DIR/complex_$i.txt" 2>&1 && echo "$(date +"%Y-%m-%d %H:%M:%S"): Teste complex_$i finalizado" &
done
wait

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

wait
echo "Iniciando processamento dos logs..."

for file in "$OUT_DIR"/*; do

    filename=$(basename "$file")
    NAME_ONLY="${filename%.*}"

    if [[ "$file" == *.csv ]] || [[ -d "$file" ]]; then
        continue
    fi

    python3 parse_sysbench.py \
        --file "$file" \
        --db "$ENGINE" \
        --type  "$NAME_ONLY" \
        --output "$OUT_DIR/resultados.csv"

done

echo "Tudo pronto! CSV gerado."