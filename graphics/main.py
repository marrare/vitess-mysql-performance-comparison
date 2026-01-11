from pathlib import Path
import argparse
from src.style import apply_paper_style
from src.io_utils import read_agg, slice_workload
from src.plots import grouped_bars, line_metric, plot_multimetric_by_scenario

def main():
    p = argparse.ArgumentParser(description="Gera figuras do estudo Vitess vs MySQL")
    p.add_argument("--data", default="data/resultados_agg.csv", help="Caminho do CSV agregado")
    p.add_argument("--out", default="figures", help="Pasta de saída das figuras")
    p.add_argument("--workloads", default="read,write,complex",
                   help="Lista separada por vírgula (ex: read,write)")

    apply_paper_style()

    ROOT = Path(__file__).resolve().parent
    df = read_agg(ROOT / "data" / "resultados_agg.csv")

    figdir = ROOT / "figures" / "sintese"
    figdir.mkdir(parents=True, exist_ok=True)

    scenarios = sorted(df["simultaneity"].unique())
    test_bases = ["read", "write", "complex", "update", "delete"]

    for tb in test_bases:
        for sc in scenarios:
            plot_multimetric_by_scenario(
                df,
                test_base=tb,
                scenario=sc,
                title=f"{tb.upper()} — {sc.capitalize()} (TPS, QPS, Lat P95)",
                outpath=figdir / f"{tb}_{sc}_sintese.png"
            )

if __name__ == "__main__":
    main()
