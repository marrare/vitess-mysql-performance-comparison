from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

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
