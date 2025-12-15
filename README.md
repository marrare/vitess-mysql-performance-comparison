
# Setup experimental

* Versão do SO (`uname -a`): `Ubuntu 24.04`
* Versão MySQL (`mysql --version`): `8.0.43`
* Versão Vitess (`vtgate --version`): `22.0.0`
* Versão Sysbench (`sysbench --version`): `sysbench 1.0.20`
---


# Tabela de mapeamento

| Nível | Sysbench (oltp_read_write)           |
| ----- | ------------------------------------ |
| Baixa | 10 tabelas × 10k linhas, 50 threads  |
| Média | 10 tabelas × 100K linhas, 50 threads |
| Alta  | 10 tabelas × 1M linhas, 50 threads   |


# Estrutura do projeto

```
├── dependencies                                    # Projetos necessários para execução dos testes
│   ├── mysql
│   ├── prometheus
│   └── vitess
├── keys
├── main.tf
├── README.md
├── scripts
│   ├── infra_down.sh                               # Desinstalar infraestrutura. Ex: source ./infra_down.sh
│   ├── infra.sh                                    # Provisionar infraestrutura. Ex: source ./infra.sh
│   ├── parse_sysbench.py                           # 
│   ├── pf_kill.sh                                  # Encerrar port-forward
│   ├── pf.sh                                       # Realizar port-forward
│   ├── run_cleanup.sh                              # 
│   ├── run_parallel.sh                             # Executa teste paralelo. Ex: ./run_parallel.sh
│   └── run_sequencial.sh                           # Executa teste sequencial. Ex: ./run_sequencial.sh
├── sysbench
│   ├── config
│   └── results                                     # Resultados do benchamrk
│       ├── aws
│       └── local
├── terraform.tfstate
└── terraform.tfstate.backup
```