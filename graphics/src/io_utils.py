from pathlib import Path
import re
import pandas as pd

SCALES = ["baixa", "media", "alta"]
METRIC_COLS = ["tps", "qps", "lat_min", "lat_avg", "lat_max", "lat_95th"]

def _clean_df(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    # normalização
    for c in METRIC_COLS + ["threads", "total_time"]:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors="coerce")
    # remove linhas 0/NaN em todas as métricas
    mask_all_zero = df[METRIC_COLS].fillna(0).eq(0).all(axis=1)
    df = df[~mask_all_zero].reset_index(drop=True)
    # rótulos
    df["database"]  = df["database"].str.strip().str.lower()
    df["scale"]     = df["scale"].str.strip().str.lower()
    df["test_type"] = df["test_type"].str.strip().str.lower()
    df["scale"] = pd.Categorical(df["scale"], categories=SCALES, ordered=True)
    # test_base sem sufixo _n
    df["test_base"] = df["test_type"].str.replace(r"_(\d+)$", "", regex=True)
    return df

def _aggregate(df: pd.DataFrame) -> pd.DataFrame:
    group_cols = ["database", "test_base", "scale"]
    agg_cols = [c for c in ["tps","qps","lat_avg","lat_95th","lat_min","lat_max"] if c in df.columns]
    agg_map = {c: ["mean","std","count"] for c in agg_cols}
    out = df.groupby(group_cols).agg(agg_map)
    out.columns = ["_".join(filter(None, col)).strip("_") for col in out.columns.to_flat_index()]
    out = out.reset_index()
    if "threads" in df.columns:
        m = df.groupby(group_cols)["threads"].agg(lambda s: s.mode().iat[0] if not s.mode().empty else s.iloc[0]).reset_index()
        out = out.merge(m, on=group_cols, how="left")
    return out

def prepare_agg(raw_path: Path, out_path: Path) -> pd.DataFrame:
    df_raw = pd.read_csv(raw_path)
    df = _clean_df(df_raw)
    df_agg = _aggregate(df)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    df_agg.to_csv(out_path, index=False)
    return df_agg

def read_agg(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    df["scale"] = pd.Categorical(df["scale"], categories=SCALES, ordered=True)
    return df

def slice_workload(df: pd.DataFrame, test_base: str) -> pd.DataFrame:
    return df[df["test_base"] == test_base].copy()
