import json
from datetime import datetime, timezone, timedelta
from pathlib import Path
import argparse
import urllib.request
import urllib.parse

PROMETHEUS_URL = "http://localhost:9090"

def query_prometheus(prom_query: str, start_time: datetime, end_time: datetime) -> dict | None:
    start_str = start_time.astimezone(timezone.utc).isoformat(timespec='milliseconds')
    end_str = end_time.astimezone(timezone.utc).isoformat(timespec='milliseconds')

    params = {
        'query': prom_query,
        'start': start_str,
        'end': end_str,
        'step': '5s'
    }

    query_string = urllib.parse.urlencode(params)
    api_url = f"{PROMETHEUS_URL}/api/v1/query_range?{query_string}"

    try:
        with urllib.request.urlopen(api_url) as response:
            data = response.read()
            return json.loads(data)
    except Exception as e:
        print(f"An error occurred while querying Prometheus: {e}")
        return None


def fetch_metrics(db: str, test_type: str, scale: str, simultaneity: str, start_dt: datetime, end_dt: datetime) -> list[dict]:
    queries = [
        ("CPU Utilization (%)", '100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)'),
        ("Memory Utilization (%)", '(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100'),
        ("Disk Read Throughput (B/s)", 'sum(rate(node_disk_read_bytes_total[1m])) by(instance)'),
        ("Disk Write Throughput (B/s)", 'sum(rate(node_disk_written_bytes_total[1m])) by(instance)'),
        ("Network Receive Throughput (B/s)", 'sum(rate(node_network_receive_bytes_total[1m])) by(instance)'),
        ("Network Transmit Throughput (B/s)", 'sum(rate(node_network_transmit_bytes_total[1m])) by(instance)')
    ]

    all_results = []
    for metric_name, promql in queries:
        data = query_prometheus(promql, start_dt, end_dt)

        if data and data.get('status') == 'success':
            for series in data['data']['result']:
                instance_label = series['metric'].get('instance', 'unknown')
                for timestamp_raw, value in series['values']:
                    all_results.append({
                        'database': db,
                        'test_type': test_type,
                        'scale': scale,
                        'simultaneity': simultaneity,
                        'metric': metric_name,
                        'instance': instance_label,
                        'timestamp': float(timestamp_raw),
                        'value': float(value)
                    })
        else:
            print(f"Query failed or returned no data for {metric_name}.")
    
    return all_results


def parse_iso8601(dt_str: str) -> datetime:
    dt_str = dt_str.replace('Z', '+00:00')
    dt = datetime.fromisoformat(dt_str)
    return dt.astimezone(timezone.utc)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fetch system metrics from Prometheus within a time range")
    parser.add_argument('--db', required=True, help='Nome do Banco (ex: MySQL, Vitess)')
    parser.add_argument('--type', required=True, help='Tipo de teste (ex: read, write, complex)')
    parser.add_argument('--scale', required=True, help='Escala de carga (ex: baixa, media, alta)')
    parser.add_argument('--simultaneity', required=True, help='Simultaneidade (ex: paralelo, sequencial)')
    parser.add_argument("--start", required=True, help="Start time in ISO 8601 format")
    parser.add_argument("--end", required=True, help="End time in ISO 8601 format")
    parser.add_argument("--output", required=True, help="Output JSON file path")
    args = parser.parse_args()

    # Ajuste para incluir margem de 1 minuto antes e depois
    start_dt = parse_iso8601(args.start)
    end_dt = parse_iso8601(args.end)
    start_dt = start_dt - timedelta(seconds=60)
    end_dt = end_dt + timedelta(seconds=60)

    # Coleta os dados
    results = fetch_metrics(args.db, args.type, args.scale, args.simultaneity, start_dt, end_dt)

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, 'w') as f:
        json.dump(results, f, indent=2)

    print(f"Saved {len(results)} records to {out_path}")