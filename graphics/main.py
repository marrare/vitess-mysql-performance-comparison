from pathlib import Path
import argparse
from src.style import apply_paper_style
from src.io_utils import read_agg
from src.plots import plot_single_metric

OP_LABEL = {
    "write": "CREATE",
    "read": "READ",
    "update": "UPDATE",
    "delete": "DELETE",
}

SCENARIO_LABEL = {
    "sequential": "Sequencial",
    "parallel": "Paralelo",
}

METRICS = [
    {
        "key": "tps",
        "col": "tps_s_mean",
        "label": "TPS",
        "y_label": "TPS (transações por segundo)",
        "fmt": "{:.0f}",
    },
    {
        "key": "lat_p95",
        "col": "lat_95th_mean",
        "label": "Latência P95",
        "y_label": "Latência P95 (ms)",
        "fmt": "{:.0f}",
    },
]


def main():
    p = argparse.ArgumentParser(description="Gera figuras do estudo Vitess vs MySQL")
    p.add_argument("--data", default="data/resultados_agg.csv", help="Caminho do CSV agregado")
    p.add_argument("--out", default="figures", help="Pasta de saída das figuras")

    apply_paper_style()

    ROOT = Path(__file__).resolve().parent
    df = read_agg(ROOT / "data" / "resultados_agg.csv")

    figdir = ROOT / "figures" / "sintese"
    figdir.mkdir(parents=True, exist_ok=True)

    test_bases = ["write", "read", "update", "delete"]
    scenarios = ["sequential", "parallel"]

    for tb in test_bases:
        for sc in scenarios:
            for metric in METRICS:
                op_name = OP_LABEL[tb]
                sc_name = SCENARIO_LABEL[sc]
                title = f"Operação {op_name} - {sc_name} - {metric['label']}"
                fname = f"{op_name.lower()}_{sc_name.lower()}_{metric['key']}.png"
                plot_single_metric(
                    df,
                    test_base=tb,
                    scenario=sc,
                    metric_col=metric["col"],
                    metric_label=metric["label"],
                    y_label=metric["y_label"],
                    title=title,
                    outpath=figdir / fname,
                    value_fmt=metric["fmt"],
                )


if __name__ == "__main__":
    main()
