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
```python
python3 -m scripts/prepare_data --in ../sysbench/results/resultados.csv --out data/resultados_agg.csv
```

## Generate graphics
```python
python3 -m main
```