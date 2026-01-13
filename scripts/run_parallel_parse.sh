#!/usr/bin/env bash
set -e

export $(grep -v '^#' ../.env | xargs)

echo "***** RUNNING PARALLEL BENCHMARKS WITH SYSBENCH *****"
echo "ENGINE: $ENGINE"
echo "SCALE: $SCALE"
echo "ENVIRONMENT: $ENVIRONMENT"
PARALLEL=10

BENCHMARK_RESULTS=../sysbench/results
OUT_DIR="${BENCHMARK_RESULTS}/${ENVIRONMENT}/${ENGINE}/${SCALE}/parallel"
mkdir -p "$OUT_DIR"

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
    fi
done

echo "Tudo pronto! CSV e JSON gerados."
