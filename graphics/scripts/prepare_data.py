from pathlib import Path
import argparse
from src.io_utils import prepare_agg

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--in",  dest="inp",  default="../sysbench/results/aws/resultados.csv")
    p.add_argument("--out", dest="outp", default="data/resultados_agg.csv")
    args = p.parse_args()
    prepare_agg(Path(args.inp), Path(args.outp))
    print(f"OK: agregado salvo em {args.outp}")
