# Tarefa
Regenerar a tabela de degradação e as frases de pitch dos slides de defesa do TCC
(Vitess vs MySQL) a partir de um novo `resultados.csv`.

## Contexto do projeto
Projeto em `/home/marciliosantos/tcc/vitess-mysql-performance-comparison/`.
Diretório de trabalho: `graphics/`.
Venv: `../.venv/bin/python`.

Pipeline:
1. `scripts/prepare_data.py` lê o CSV bruto em `../sysbench/results/aws/resultados.csv`
   e gera `data/resultados_agg.csv` (médias por combo).
2. `scripts/build_degradation.py` gera `data/degradacao.csv`.
3. `scripts/build_degradation_xlsx.py` gera `data/degradacao.xlsx` (com fórmulas vivas).
4. `main.py` gera os 16 PNGs em `figures/sintese/`.

CSV bruto esperado: colunas
`timestamp_start,timestamp_end,database,test_type,scale,simultaneity,threads,total_time,tps,qps,lat_min,lat_avg,lat_max,lat_95th`
- `tps` e `qps` são **contagens totais** (não rates); o pipeline divide por `total_time`.
- `test_type` = `{write,read,update,delete}_{1..10}` (10 reps por combo).
- `scale` ∈ `{baixa, media, alta}` (100K, 1M, 10M). Ignorar `big`.
- `simultaneity` ∈ `{sequencial, paralelo}`.

## Passos

1. Substituir o arquivo `../sysbench/results/aws/resultados.csv` pelo novo CSV.
2. Rodar:
   ```
   ../.venv/bin/python -m scripts.prepare_data
   ../.venv/bin/python -m scripts.build_degradation
   ../.venv/bin/python -m scripts.build_degradation_xlsx
   ../.venv/bin/python main.py
   ```
3. Validar 1 combo conhecido (ex.: parsear os 10 `.txt` de
   `../sysbench/results/aws/mysql/baixa/parallel/write_*.txt`, extrair "transactions: N (X per sec.)"
   e comparar a média com `data/resultados_agg.csv`).

## Tabela de degradação (4 tabelas — uma por operação)

Formato: **% de degradação** (valores positivos = piorou).
Sinais: TPS negativo no raw → positivo na tabela (queda); Lat P95 positivo no raw → positivo
na tabela (aumento). Quando a latência **melhorou** (delta negativo), marcar com `↓`.
Arredondar a inteiro. Coluna "Δ 100K → 10M".

Template:
```
### {OPERACAO} — Degradação 100K → 10M
|              |   TPS   | Lat P95 |
|--------------|--------:|--------:|
| Seq · MySQL  |   X%    |   X%    |
| Seq · Vitess |   X%    |   X%    |
| Par · MySQL  |   X%    |   X%    |
| Par · Vitess |   X%    |   X%    |
```

## Frases de slide (para cada operação: CREATE, READ, UPDATE, DELETE)

Estrutura fixa por slide:
- **Barra verde** (uppercase, ≤ 50 chars) — manchete com a tese principal do slide.
- **Texto verde** (1 frase) — enquadra o mecanismo técnico envolvido na operação.
- **3 bullets** — explicação técnica, cada um curto e específico.
- **Frase preta** (impactante, com número) — fecha com o maior contraste numérico
  (use **fator multiplicativo** da latência ou queda % do TPS — o que tiver mais impacto).
- **Pitch falado** (2–4 frases, ~15 s) — conta a história usando 1–2 números chave
  e explicita o tradeoff "MySQL ganha absoluto / Vitess ganha estabilidade".

Regras:
- Usar **fator multiplicativo** (`new/base`) quando contar histórias de latência
  (ex.: "multiplica por 17"), e **% de queda** quando contar TPS
  (ex.: "perde 85% do TPS").
- Não confundir "sequencial" do cenário (1 thread) com "I/O sequencial" em disco.
- Para a queda de TPS do MySQL ao escalar, prefira a explicação de
  **working set saindo do buffer pool** + **profundidade do B+tree** + **manutenção
  de índices secundários**, em vez de "fragmentação" (que é efeito de segunda ordem).
- Para Vitess, citar **vtgate roteando e mantendo cache de metadados**, **vttablet
  coordenando com a réplica do shard antes do commit**, e **overhead fixo por operação**.

## Saída esperada

1. As 4 tabelas de degradação atualizadas.
2. Para cada operação (CREATE, READ, UPDATE, DELETE):
   - Barra verde
   - Texto verde
   - 3 bullets
   - Frase preta
   - Pitch falado
3. Validar que os fatores numéricos citados nas frases batem com o CSV.
