from pathlib import Path
import pandas as pd
from src.io_utils import read_agg

OP_LABEL = {"write": "CREATE", "read": "READ", "update": "UPDATE", "delete": "DELETE"}
SCENARIO_LABEL = {"sequential": "Sequencial", "parallel": "Paralelo"}
SCALES = ["baixa", "media", "alta"]


def pct_change(new, base):
    if pd.isna(new) or pd.isna(base) or base == 0:
        return None
    return (new - base) / base * 100.0


def build_degradation(df: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for db in ["mysql", "vitess"]:
        for tb, op in OP_LABEL.items():
            for sc, sc_label in SCENARIO_LABEL.items():
                sub = df[
                    (df["database"] == db)
                    & (df["test_base"] == tb)
                    & (df["simultaneity"] == sc)
                ]

                def get(col, scale):
                    r = sub[sub["scale"] == scale]
                    if r.empty:
                        return None
                    v = r[col].iloc[0]
                    return None if pd.isna(v) else float(v)

                tps = {s: get("tps_s_mean", s) for s in SCALES}
                lat = {s: get("lat_95th_mean", s) for s in SCALES}

                rows.append({
                    "database": db,
                    "operation": op,
                    "scenario": sc_label,
                    "tps_100K": tps["baixa"],
                    "tps_1M": tps["media"],
                    "tps_10M": tps["alta"],
                    "lat_p95_100K": lat["baixa"],
                    "lat_p95_1M": lat["media"],
                    "lat_p95_10M": lat["alta"],
                    "delta_tps_100K_1M_pct": pct_change(tps["media"], tps["baixa"]),
                    "delta_tps_1M_10M_pct": pct_change(tps["alta"], tps["media"]),
                    "delta_tps_100K_10M_pct": pct_change(tps["alta"], tps["baixa"]),
                    "delta_lat_100K_1M_pct": pct_change(lat["media"], lat["baixa"]),
                    "delta_lat_1M_10M_pct": pct_change(lat["alta"], lat["media"]),
                    "delta_lat_100K_10M_pct": pct_change(lat["alta"], lat["baixa"]),
                })
    return pd.DataFrame(rows)


if __name__ == "__main__":
    ROOT = Path(__file__).resolve().parent.parent
    df = read_agg(ROOT / "data" / "resultados_agg.csv")
    out = build_degradation(df)
    out_path = ROOT / "data" / "degradacao.csv"
    out.to_csv(out_path, index=False, float_format="%.2f")
    print(f"OK: salvo em {out_path}")
