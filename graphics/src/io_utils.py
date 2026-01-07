from pathlib import Path
import pandas as pd
import numpy as np

SCALES = ["baixa", "media", "alta"]
METRIC_COLS = ["tps","qps","lat_min","lat_avg","lat_max","lat_95th"]

def _clean_df(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()

    # 1) total_time: "60.1675s" -> 60.1675 (segundos)
    if "total_time" in df.columns:
        df["total_time_s"] = (
            df["total_time"].astype(str).str.strip().str.replace("s", "", regex=False)
        )
        df["total_time_s"] = pd.to_numeric(df["total_time_s"], errors="coerce")
    else:
        df["total_time_s"] = np.nan

    # 2) converter métricas para float (latências já são ms)
    for c in METRIC_COLS + ["threads"]:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors="coerce")

    # 3) TPS/QPS por segundo (se tps/qps forem valores brutos)
    if {"tps", "total_time_s"}.issubset(df.columns):
        df["tps_s"] = df["tps"] / df["total_time_s"]
    if {"qps", "total_time_s"}.issubset(df.columns):
        df["qps_s"] = df["qps"] / df["total_time_s"]

    # 4) remover linhas onde tudo está 0/NaN
    cols_check = [c for c in ["tps_s","qps_s","lat_min","lat_avg","lat_max","lat_95th"] if c in df.columns]
    mask_all_zero = df[cols_check].fillna(0).eq(0).all(axis=1)
    df = df[~mask_all_zero].reset_index(drop=True)

    # 5) rótulos/categorias
    df["database"]  = df["database"].astype(str).str.strip().str.lower()
    df["scale"]     = df["scale"].astype(str).str.strip().str.lower()
    df["test_type"] = df["test_type"].astype(str).str.strip().str.lower()
    df["scale"] = pd.Categorical(df["scale"], categories=SCALES, ordered=True)

    # test_base sem sufixo _n (réplicas)
    df["test_base"] = df["test_type"].str.replace(r"_(\d+)$", "", regex=True)

    # 6) cenário
    if "simultaneity" not in df.columns:
        raise ValueError("Coluna 'simultaneity' não encontrada (esperado: paralelo/sequencial).")

    df["simultaneity"] = df["simultaneity"].astype(str).str.strip().str.lower()
    df["simultaneity"] = df["simultaneity"].replace({
        "sequencial": "sequential",
        "paralelo": "parallel",
    })

    return df


def _aggregate(df: pd.DataFrame) -> pd.DataFrame:
    GROUP_COLS = ["database", "test_base", "scale", "simultaneity"]

    agg_cols = [c for c in ["tps_s","qps_s","lat_avg","lat_95th","lat_min","lat_max","total_time_s"] if c in df.columns]
    agg_map = {c: ["mean","std","count"] for c in agg_cols}

    out = df.groupby(GROUP_COLS).agg(agg_map)
    out.columns = ["_".join(filter(None, col)).strip("_") for col in out.columns.to_flat_index()]
    out = out.reset_index()

    if "threads" in df.columns:
        threads_mode = (
            df.groupby(GROUP_COLS)["threads"]
              .agg(lambda s: s.mode().iat[0] if not s.mode().empty else s.iloc[0])
              .reset_index()
        )
        out = out.merge(threads_mode, on=GROUP_COLS, how="left")

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
