# Graphics Generation

## Install dependencies
```bash
pip install -r requirements.txt
```

## Prepare aggregated data
```python
python scripts/prepare_data.py --in ../sysbench/results/resultados.csv --out data/resultados_agg.csv
```

## Generate graphics
```python
python3 -m main
```