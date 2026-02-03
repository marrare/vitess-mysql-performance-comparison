#!/usr/bin/env python3
import json
import argparse
from datetime import datetime, timezone
import boto3

boto3.setup_default_session(profile_name='tcc')

def parse_iso(ts: str) -> datetime:
    # Ex: 2026-01-13T21:24:27+00:00
    return datetime.fromisoformat(ts).astimezone(timezone.utc)

def get_private_dns(ec2, instance_id: str) -> str:
    resp = ec2.describe_instances(InstanceIds=[instance_id])
    r = resp["Reservations"][0]["Instances"][0]
    return r.get("PrivateDnsName") or instance_id

def build_metric_queries(instance_id: str, period: int):
    dims = [{"Name": "InstanceId", "Value": instance_id}]

    # SEARCH precisa do InstanceId "hardcoded" na expressão
    disk_search = (
        f"SEARCH('{{CWAgent,InstanceId}} MetricName=\"disk_used_percent\" "
        f"AND InstanceId=\"{instance_id}\"', 'Average', {period})"
    )

    return [
        # CPU (%)
        {
            "Id": "m_cpu",
            "MetricStat": {
                "Metric": {"Namespace": "AWS/EC2", "MetricName": "CPUUtilization", "Dimensions": dims},
                "Period": period,
                "Stat": "Average",
            },
            "ReturnData": True,
            "Label": "CPU Utilization (%)",
        },

        # Memory (%): OK com InstanceId
        {
            "Id": "m_mem_used_pct",
            "MetricStat": {
                "Metric": {"Namespace": "CWAgent", "MetricName": "mem_used_percent", "Dimensions": dims},
                "Period": period,
                "Stat": "Average",
            },
            "ReturnData": True,
            "Label": "Memory Utilization (%)",
        },

        # Disk Utilization (%): várias séries -> SEARCH + agregação
        # 1) busca todas as séries disk_used_percent daquele InstanceId
        {
            "Id": "m_disk_used_pct_all",
            "Expression": disk_search,
            "ReturnData": False,
        },
        # 2) agrega (recomendo MAX para refletir “pior disco”, e ficar mais próximo de alertas)
        {
            "Id": "e_disk_used_pct",
            "Expression": "MAX(m_disk_used_pct_all)",
            "ReturnData": True,
            "Label": "Disk Utilization (%)",
        },

        # Disk Read Throughput (B/s)
        {
            "Id": "m_disk_read_bytes",
            "MetricStat": {
                "Metric": {"Namespace": "AWS/EC2", "MetricName": "DiskReadBytes", "Dimensions": dims},
                "Period": period,
                "Stat": "Sum",
            },
            "ReturnData": False,
        },
        {
            "Id": "e_disk_read_bps",
            "Expression": "m_disk_read_bytes / PERIOD(m_disk_read_bytes)",
            "ReturnData": True,
            "Label": "Disk Read Throughput (B/s)",
        },

        # Disk Write Throughput (B/s)
        {
            "Id": "m_disk_write_bytes",
            "MetricStat": {
                "Metric": {"Namespace": "AWS/EC2", "MetricName": "DiskWriteBytes", "Dimensions": dims},
                "Period": period,
                "Stat": "Sum",
            },
            "ReturnData": False,
        },
        {
            "Id": "e_disk_write_bps",
            "Expression": "m_disk_write_bytes / PERIOD(m_disk_write_bytes)",
            "ReturnData": True,
            "Label": "Disk Write Throughput (B/s)",
        },

        # Network Receive Throughput (B/s)
        {
            "Id": "m_net_in",
            "MetricStat": {
                "Metric": {"Namespace": "AWS/EC2", "MetricName": "NetworkIn", "Dimensions": dims},
                "Period": period,
                "Stat": "Sum",
            },
            "ReturnData": False,
        },
        {
            "Id": "e_net_in_bps",
            "Expression": "m_net_in / PERIOD(m_net_in)",
            "ReturnData": True,
            "Label": "Network Receive Throughput (B/s)",
        },

        # Network Transmit Throughput (B/s)
        {
            "Id": "m_net_out",
            "MetricStat": {
                "Metric": {"Namespace": "AWS/EC2", "MetricName": "NetworkOut", "Dimensions": dims},
                "Period": period,
                "Stat": "Sum",
            },
            "ReturnData": False,
        },
        {
            "Id": "e_net_out_bps",
            "Expression": "m_net_out / PERIOD(m_net_out)",
            "ReturnData": True,
            "Label": "Network Transmit Throughput (B/s)",
        },
    ]

def collect_timeseries_json(
    region: str,
    instance_id: str,
    start: datetime,
    end: datetime,
    period: int,
    database: str,
    test_type: str,
    scale: str,
    simultaneity: str,
):
    cw = boto3.client("cloudwatch", region_name=region)
    ec2 = boto3.client("ec2", region_name=region)

    instance_name = get_private_dns(ec2, instance_id)
    queries = build_metric_queries(instance_id, period)

    out = []
    next_token = None

    # Para "diferença a partir do timestamp": usamos offset relativo ao start
    start_epoch = start.timestamp()

    while True:
        kwargs = dict(
            MetricDataQueries=queries,
            StartTime=start,
            EndTime=end,
            ScanBy="TimestampAscending",
            MaxDatapoints=1000,
        )
        if next_token:
            kwargs["NextToken"] = next_token

        resp = cw.get_metric_data(**kwargs)

        for r in resp.get("MetricDataResults", []):
            label = r.get("Label") or r.get("Id")
            timestamps = r.get("Timestamps", [])
            values = r.get("Values", [])

            # CloudWatch pode retornar timestamps/values em ordens diferentes em alguns casos,
            # mas com ScanBy=TimestampAscending geralmente já vem ordenado.
            for ts, val in zip(timestamps, values):
              
                # ts vindo do boto3 geralmente já é timezone-aware
                epoch = ts.timestamp()
                if epoch < start_epoch or epoch > end.timestamp():
                    continue  # garante que não entra ponto fora do intervalo

                offset_s = float(epoch - start_epoch)

                out.append({
                    "database": database,
                    "test_type": test_type,
                    "scale": scale,
                    "simultaneity": simultaneity,
                    "metric": label,
                    "instance": instance_name,
                    "timestamp": offset_s,   # <- diferença (segundos desde StartDate)
                    "value": float(val),
                    # Se você quiser manter o epoch também, descomente:
                    # "timestamp_epoch": float(epoch),
                })

        next_token = resp.get("NextToken")
        if not next_token:
            break

    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--region", required=True)
    ap.add_argument("--instance-id", required=True)
    ap.add_argument("--start", required=True, help="ISO8601, ex: 2026-01-13T21:24:27+00:00")
    ap.add_argument("--end", required=True, help="ISO8601, ex: 2026-01-13T21:25:30+00:00")
    ap.add_argument("--period", type=int, default=5)

    ap.add_argument("--database", required=True)      # mysql | vitess
    ap.add_argument("--test-type", required=True)     # read | write | delete | update
    ap.add_argument("--scale", required=True)         # baixa | media | alta
    ap.add_argument("--simultaneity", required=True)  # paralelo | sequencial

    args = ap.parse_args()

    start = parse_iso(args.start)
    end = parse_iso(args.end)

    data = collect_timeseries_json(
        region=args.region,
        instance_id=args.instance_id,
        start=start,
        end=end,
        period=args.period,
        database=args.database,
        test_type=args.test_type,
        scale=args.scale,
        simultaneity=args.simultaneity,
    )

    print(json.dumps(data, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
