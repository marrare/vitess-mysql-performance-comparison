import re
import csv
import sys
import argparse
from datetime import datetime
import os

def parse_sysbench_log(file_path, db_type, test_type, timestamp):
    # Dicionário para armazenar os resultados
    data = {
        "timestamp": timestamp,
        "database": db_type,
        "test_type": test_type,
        "total_time": 0,
        "threads": 0,
        "tps": 0,    # Transactions per second
        "qps": 0,    # Queries per second
        "lat_min": 0,
        "lat_avg": 0,
        "lat_max": 0,
        "lat_95th": 0
    }

    try:
        with open(file_path, 'r') as f:
            content = f.read()
            
            # Extração via Regex (Expressões Regulares)
            # 1. Threads
            match_threads = re.search(r"Number of threads:\s+(\d+)", content)
            if match_threads: data["threads"] = match_threads.group(1)

            # 2. Total Time
            match_time = re.search(r"total time:\s+([\d\.]+)s", content)
            if match_time: data["total_time"] = match_time.group(1)

            # 3. TPS (Transactions per sec)
            match_tps = re.search(r"transactions:.*\(([\d\.]+) per sec\.\)", content)
            if match_tps: data["tps"] = match_tps.group(1)

            # 4. QPS (Queries per sec)
            match_qps = re.search(r"queries:.*\(([\d\.]+) per sec\.\)", content)
            if match_qps: data["qps"] = match_qps.group(1)

            # 5. Latencies (min, avg, max, 95th)
            match_lat_min = re.search(r"min:\s+([\d\.]+)", content)
            if match_lat_min: data["lat_min"] = match_lat_min.group(1)
            
            match_lat_avg = re.search(r"avg:\s+([\d\.]+)", content)
            if match_lat_avg: data["lat_avg"] = match_lat_avg.group(1)
            
            match_lat_max = re.search(r"max:\s+([\d\.]+)", content)
            if match_lat_max: data["lat_max"] = match_lat_max.group(1)
            
            match_lat_95 = re.search(r"95th percentile:\s+([\d\.]+)", content)
            if match_lat_95: data["lat_95th"] = match_lat_95.group(1)

        return data

    except FileNotFoundError:
        print(f"Erro: Arquivo '{file_path}' não encontrado.")
        sys.exit(1)

def append_to_csv(data, output_csv='resultados_tcc.csv'):
    file_exists = os.path.isfile(output_csv)
    
    # Ordem das colunas
    fieldnames = [
        "timestamp", "database", "test_type", "threads", 
        "total_time", "tps", "qps", "lat_min", "lat_avg", "lat_max", "lat_95th"
    ]

    with open(output_csv, 'a', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        
        if not file_exists:
            writer.writeheader()  # Escreve o cabeçalho se o arquivo for novo
        
        writer.writerow(data)
    
    print(f"Sucesso! Dados de '{data['database']}' adicionados ao CSV.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Parser de Logs do Sysbench para CSV')
    parser.add_argument('--file', required=True, help='Caminho do arquivo de log')
    parser.add_argument('--db', required=True, help='Nome do Banco (ex: MySQL, Vitess)')
    parser.add_argument('--type', required=True, help='Tipo de teste (ex: read, write, complex)')
    parser.add_argument('--output', required=True, help='Arquivo CSV de saída (padrão: resultados_tcc.csv)')
    
    args = parser.parse_args()
    
    # Pega o timestamp atual para registrar o momento da execução
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    parsed_data = parse_sysbench_log(args.file, args.db, args.type, now)
    append_to_csv(parsed_data, args.output)