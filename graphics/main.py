from pathlib import Path
import argparse
from src.style import apply_paper_style
from src.io_utils import read_agg, slice_workload
from src.plots import grouped_bars, line_metric

WORKLOADS = ["read", "write", "complex"]

def make_figs(figdir: Path, dfpath: Path, workloads: list[str]):
    apply_paper_style()
    df = read_agg(dfpath)

    # 1) Throughput (TPS) — barras
    for w in workloads:
        grouped_bars(
            slice_workload(df, w),
            value_col="tps_mean",
            title=f"Throughput (TPS) — {w.upper()} por escala (MySQL vs Vitess)",
            y_label="TPS (média)",
            outpath=figdir / f"tps_{w}.png",
        )

    # 2) Latência média — barras
    for w in workloads:
        grouped_bars(
            slice_workload(df, w),
            value_col="lat_avg_mean",
            title=f"Latência média — {w.upper()} por escala (MySQL vs Vitess)",
            y_label="Latência média (ms)",
            outpath=figdir / f"lat_avg_{w}.png",
        )

    # 3) Latência P95 — linhas (escala log)
    for w in workloads:
        line_metric(
            slice_workload(df, w),
            value_col="lat_95th_mean",
            title=f"Latência P95 — {w.upper()} por escala (MySQL vs Vitess)",
            y_label="Latência P95 (ms, escala log)",
            outpath=figdir / f"lat_p95_{w}.png",
            y_log=True,
        )

    # 4) Figura síntese — COMPLEX (TPS + P95 em arquivos separados)
    w = "complex"
    grouped_bars(
        slice_workload(df, w),
        value_col="tps_mean",
        title="Throughput (TPS) — COMPLEX por escala",
        y_label="TPS (média)",
        outpath=figdir / "fig_sintese_complex_tps.png",
    )
    line_metric(
        slice_workload(df, w),
        value_col="lat_95th_mean",
        title="Latência P95 — COMPLEX por escala",
        y_label="Latência P95 (ms, escala log)",
        outpath=figdir / "fig_sintese_complex_p95.png",
        y_log=True,
    )

def main():
    p = argparse.ArgumentParser(description="Gera figuras do estudo Vitess vs MySQL")
    p.add_argument("--data", default="data/resultados_agg.csv", help="Caminho do CSV agregado")
    p.add_argument("--out", default="figures", help="Pasta de saída das figuras")
    p.add_argument("--workloads", default="read,write,complex",
                   help="Lista separada por vírgula (ex: read,write)")
    args = p.parse_args()

    dfpath = Path(args.data)
    figdir = Path(args.out)
    workloads = [w.strip().lower() for w in args.workloads.split(",") if w.strip()]

    make_figs(figdir, dfpath, workloads)

if __name__ == "__main__":
    main()
