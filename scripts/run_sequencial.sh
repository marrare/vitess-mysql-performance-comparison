#!/usr/bin/env bash
set -e

export $(grep -v '^#' ../.env | xargs)

echo "***** RUNNING SEQUENCIAL BENCHMARKS WITH SYSBENCH *****"
echo "ENGINE: $ENGINE"
echo "SCALE: $SCALE"
echo "ENVIRONMENT: $ENVIRONMENT"
SEQUENCIAL=2

./run_cleanup.sh

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
OUT_DIR="${BENCHMARK_RESULTS}/${ENVIRONMENT}/${ENGINE}/${SCALE}/sequencial"
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
INITIALIZE_TIME=$(date --iso-8601=seconds)
for i in $(seq 1 $SEQUENCIAL); do
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
  run > "$OUT_DIR/read_$i.txt" 2>&1 && echo "$(date +"%Y-%m-%d %H:%M:%S"): Teste read_$i finalizado"
done
wait
FINALIZE_TIME=$(date --iso-8601=seconds)
echo -e "Start: $INITIALIZE_TIME\nEnd: $FINALIZE_TIME" >> "$OUT_DIR/read.txt"

sleep 120

# write
INITIALIZE_TIME=$(date --iso-8601=seconds)
for i in $(seq 1 $SEQUENCIAL); do
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
  run > "$OUT_DIR/write_$i.txt" 2>&1 && echo "$(date +"%Y-%m-%d %H:%M:%S"): Teste write_$i finalizado"
done
wait
FINALIZE_TIME=$(date --iso-8601=seconds)
echo -e "Start: $INITIALIZE_TIME\nEnd: $FINALIZE_TIME" >> "$OUT_DIR/write.txt"

sleep 120

# update
INITIALIZE_TIME=$(date --iso-8601=seconds)
for i in $(seq 1 $SEQUENCIAL); do
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
  run > "$OUT_DIR/update_$i.txt" 2>&1 && echo "$(date +"%Y-%m-%d %H:%M:%S"): Teste update_$i finalizado"
done
wait
FINALIZE_TIME=$(date --iso-8601=seconds)
echo -e "Start: $INITIALIZE_TIME\nEnd: $FINALIZE_TIME" >> "$OUT_DIR/update.txt"

sleep 120

# complex (read+write)
INITIALIZE_TIME=$(date --iso-8601=seconds)
for i in $(seq 1 $SEQUENCIAL); do
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
  run > "$OUT_DIR/complex_$i.txt" 2>&1 && echo "$(date +"%Y-%m-%d %H:%M:%S"): Teste complex_$i finalizado"
done
wait
FINALIZE_TIME=$(date --iso-8601=seconds)
echo -e "Start: $INITIALIZE_TIME\nEnd: $FINALIZE_TIME" >> "$OUT_DIR/complex.txt"

sleep 120

# delete
INITIALIZE_TIME=$(date --iso-8601=seconds)
for i in $(seq 1 $SEQUENCIAL); do
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
  run > "$OUT_DIR/delete_$i.txt" 2>&1 && echo "$(date +"%Y-%m-%d %H:%M:%S"): Teste delete_$i finalizado"
done
wait
FINALIZE_TIME=$(date --iso-8601=seconds)
echo -e "Start: $INITIALIZE_TIME\nEnd: $FINALIZE_TIME" >> "$OUT_DIR/delete.txt"


echo "Iniciando processamento dos logs e métricas..."
for file in "$OUT_DIR"/*; do
    if [[ "$file" == *.csv ]] || [[ "$file" == *.json ]] || [[ -d "$file" ]]; then
        continue
    fi

    filename=$(basename "$file")
    NAME_ONLY="${filename%.*}"
    NAME_FILE_TIMESTAMP="${filename%_*}"
    if [[ "$NAME_FILE_TIMESTAMP" != *.txt ]]; then
      NAME_FILE_TIMESTAMP="$NAME_FILE_TIMESTAMP.txt"
    fi

    CONTENT=$(<"$OUT_DIR/$NAME_FILE_TIMESTAMP")
    START=$(echo "$CONTENT" | grep -oP 'Start:\s*\K.*')
    END=$(echo "$CONTENT" | grep -oP 'End:\s*\K.*')

    if [[ "$NAME_ONLY" =~ [0-9] ]]; then
      python3 parse_sysbench.py \
        --file "$file" \
        --db "$ENGINE" \
        --type  "$NAME_ONLY" \
        --scale  "$SCALE" \
        --simultaneity "paralelo" \
        --start "$START" \
        --end "$END" \
        --output "$BENCHMARK_RESULTS/$ENVIRONMENT/resultados.csv"
      wait
    else 
      FILE_METRICS="${NAME_ONLY%_[0-9]*}"
      python3 collect_hardware_metrics.py \
        --db "$ENGINE" \
        --type  "$FILE_METRICS" \
        --scale  "$SCALE" \
        --simultaneity "paralelo" \
        --start "$START" \
        --end "$END" \
        --output "$OUT_DIR/${FILE_METRICS}.json"
      wait
    fi
done

echo "Tudo pronto! CSV e JSON gerados."