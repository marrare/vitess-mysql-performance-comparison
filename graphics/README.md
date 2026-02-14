# Graphics Generation

## Activate Python Environment

```bash
source .venv/bin/activate
```

## Install dependencies

```bash
pip install -r requirements.txt
```

## Prepare aggregated data

```bash
python3 -m scripts.prepare_data --in ../sysbench/results/aws/resultados.csv --out data/resultados_agg.csv
```

## Generate graphics

```bash
python3 -m main
```
