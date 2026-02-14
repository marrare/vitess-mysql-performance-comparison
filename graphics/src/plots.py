from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

def plot_multimetric_by_scenario(
    df: pd.DataFrame,
    test_base: str,
    scenario: str,
    title: str,
    outpath: Path,
    tps_col: str = "tps_s_mean",
    qps_col: str = "qps_s_mean",
    lat_col: str = "lat_95th_mean",
    x_col: str = "scale",
    db_col: str = "database",
    scenario_col: str = "simultaneity",
):
    data = df[(df["test_base"] == test_base) & (df[scenario_col] == scenario)].copy()
    if data.empty:
        raise ValueError(f"Sem dados para test_base='{test_base}' e scenario='{scenario}'.")

    # Marcadores: Vitess quadrado, MySQL triângulo
    # marker_by_db = {"vitess": "s", "mysql": "^"}

    marker_by_db = {"vitess": "o", "mysql": "o"}
    linestyle_by_db = {"vitess": "--", "mysql": "-"}

    fig, ax_left = plt.subplots(figsize=(7, 4.5))
    ax_right = ax_left.twinx()

    # -------------------------
    # MÉTRICAS DAS MESMAS CORES
    # -------------------------
    color_cycle = plt.rcParams["axes.prop_cycle"].by_key()["color"]
    metric_color = {
        "TPS": color_cycle[0],
        "QPS": color_cycle[1],
        "LAT": color_cycle[2],
    }

    # -------------------------
    # EIXO ESQUERDO — TPS / QPS
    # -------------------------
    for col, metric_label in [
        (tps_col, "TPS"),
        (qps_col, "QPS"),
    ]:
        color = metric_color["TPS"] if metric_label == "TPS" else metric_color["QPS"]
        # Diferenciar visualmente TPS e QPS pois podem se sobrepor
        if metric_label == "TPS":
            lw = 2.5
            ms = 6
            zorder = 3
        else:
            lw = 1.5
            ms = 4
            zorder = 4  # QPS por cima, mas menor/mais fina

        for db in ["vitess", "mysql"]:
            d = data[data[db_col] == db].sort_values(x_col)
            ax_left.plot(
                d[x_col].astype(str),
                d[col].values,
                color=color,
                linestyle=linestyle_by_db.get(db, "-"),
                linewidth=lw,
                marker=marker_by_db.get(db, "o"),
                markersize=ms,
                zorder=zorder,
                label=f"{metric_label} — {db.capitalize()}",
            )

            annotate_points(
                ax_left,
                d[x_col].astype(str),
                d[col].values,
                fmt="{:.0f}",
                dy=6
            )

    ax_left.set_ylabel("TPS e QPS (operações por segundo)")
    ax_left.set_xlabel("Carga")

    # -------------------------
    # EIXO DIREITO — LATÊNCIA
    # -------------------------
    for db in ["vitess", "mysql"]:
        d = data[data[db_col] == db].sort_values(x_col)
        ax_right.plot(
            d[x_col].astype(str),
            d[lat_col].values,
            color=metric_color["LAT"],
            linestyle=linestyle_by_db.get(db, "-"),
            marker=marker_by_db.get(db, "o"),
            markersize=3,
            label=f"Lat P95 — {db.capitalize()}",
        )

        annotate_points(
            ax_right,
            d[x_col].astype(str),
            d[lat_col].values,
            fmt="{:.0f}",   # ms inteiros
            dy=6
        )

    ax_right.set_ylabel("Lat P95 (milissegundos)")
    
    # -------------------------
    # TÍTULO + LEGENDA
    # -------------------------
    ax_left.set_title(title)

    lines_l, labels_l = ax_left.get_legend_handles_labels()
    lines_r, labels_r = ax_right.get_legend_handles_labels()
    ax_left.legend(
        lines_l + lines_r,
        labels_l + labels_r,
        fontsize=9,
        ncols=1,
    )

    fig.tight_layout()
    outpath.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(outpath, dpi=300, bbox_inches="tight")
    plt.close(fig)

def annotate_points(ax, x, y, fmt="{:.1f}", dy=5):
    """
    ax : eixo matplotlib
    x  : valores do eixo X (strings ou números)
    y  : valores do eixo Y
    fmt: formato do texto
    dy : deslocamento vertical (em pontos)
    """
    for xi, yi in zip(x, y):
        if yi is None or pd.isna(yi):
            continue
        ax.annotate(
            fmt.format(yi),
            (xi, yi),
            textcoords="offset points",
            xytext=(0, dy),
            ha="center",
            fontsize=7,
            alpha=0.7,
        )

def _pivot(df: pd.DataFrame, value_col: str, x_col="scale", hue_col="database"):
    pivot = (df.pivot_table(index=x_col, columns=hue_col,
                            values=value_col, aggfunc="first")
             .sort_index())
    return pivot

def grouped_bars(df: pd.DataFrame, value_col: str, title: str, y_label: str,
                 outpath: Path, x_col: str="scale", hue_col: str="database",
                 x_label: str="Escala de carga"):
    pivot = _pivot(df, value_col, x_col, hue_col)
    x = np.arange(len(pivot.index))
    width = 0.35
    fig, ax = plt.subplots()
    if "mysql" in pivot.columns:
        ax.bar(x - width/2, pivot["mysql"].values, width, label="MySQL")
    if "vitess" in pivot.columns:
        ax.bar(x + width/2, pivot["vitess"].values, width, label="Vitess")
    ax.set_xlabel(x_label)
    ax.set_ylabel(y_label)
    ax.set_title(title)
    ax.set_xticks(x)
    ax.set_xticklabels([str(i) for i in pivot.index])
    ax.legend()
    fig.tight_layout()
    outpath.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(outpath)

def line_metric(df: pd.DataFrame, value_col: str, title: str, y_label: str,
                outpath: Path, x_col: str="scale", hue_col: str="database",
                x_label: str="Escala de carga", y_log: bool=False):
    pivot = _pivot(df, value_col, x_col, hue_col)
    fig, ax = plt.subplots()
    for col in pivot.columns:
        ax.plot(pivot.index.astype(str), pivot[col].values, marker="o", label=col.capitalize())
    ax.set_xlabel(x_label)
    ax.set_ylabel(y_label)
    if y_log:
        ax.set_yscale("log")
    ax.set_title(title)
    ax.legend()
    fig.tight_layout()
    outpath.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(outpath)
