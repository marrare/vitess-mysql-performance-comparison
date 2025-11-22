
# Setup experimental
* Environment: Ubuntu Marcílio
* Versão do SO (`uname -a`):  `Linux marcililiosantos 6.14.0-35-generic #35~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC Tue Oct 14 13:55:17 UTC 2 x86_64 x86_64 x86_64 GNU/Linux`
* Versão MySQL (`mysql --version`): `mysql  Ver 8.0.43-0ubuntu0.24.04.2 for Linux on x86_64 ((Ubuntu))`
* Versão Vitess (`vtgate --version`): `23.0.0 (Git revision bee41a670a0e18e7400364712263bab171ee89dc branch 'HEAD') built on Tue Nov  4 14:39:33 UTC 2025 by runner@runnervmf2e7y using go1.25.1 linux/amd64`
* Versão Sysbench (`sysbench --version`): `sysbench 1.0.20`
* Versão BenchBase: 5af9d97788ee349f7223f9b7a3bb651202ce3a4f (main)

---

## 1. Build BenchBase

Na pasta do BenchBase
```bash
./mvnw clean package -P mysql
```
Isso deve gerar algo como:
```bash
Results :

Tests run: 247, Failures: 0, Errors: 0, Skipped: 5

[INFO] 
[INFO] --- maven-jar-plugin:3.4.2:jar (default-jar) @ benchbase ---
[INFO] Building jar: /home/marciliosantos/tcc/benchbase/target/benchbase-2023-SNAPSHOT-mysql.jar
[INFO] 
[INFO] --- maven-assembly-plugin:3.7.1:single (default) @ benchbase ---
[INFO] Reading assembly descriptor: src/main/assembly/tgz.xml
[INFO] Reading assembly descriptor: src/main/assembly/zip.xml
[INFO] Building tar: /home/marciliosantos/tcc/benchbase/target/benchbase-mysql.tgz
[INFO] Building zip: /home/marciliosantos/tcc/benchbase/target/benchbase-mysql.zip
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  05:17 min
[INFO] Finished at: 2025-11-20T23:20:54-03:00
[INFO] ------------------------------------------------------------------------
```

## 2. Descompacta

```bash
cd target
tar xvf benchbase-mysql.tgz
```
## 3. Definir variável com path do BenchBase 

```bash
export BENCHBASE_HOME=<vitess-mysql-notes-repository-path>/benchmarks/benchbase
```

## 4. Mover pasta benchbase-mysql para a pasta $BENCHBASE_HOME

```
mv benchbase-mysql $BENCHBASE_HOME
cd $BENCHBASE_HOME
```

## 4. Cria as pastas de resultados

```bash
mkdir -p $BENCHBASE_HOME/results/local/benchbase/mysql/{baixa,media,alta}
mkdir -p $BENCHBASE_HOME/results/local/benchbase/vitess/{baixa,media,alta}
```

## 5. Execução de teste do MySQL Local

Dentro da pasta do benchbase-mysql
```bash
java -jar benchbase.jar \                       
  -b tpcc \
  -c ../config/tpcc_mysql_baixa.xml \
  --create=true \
  --load=true \
  --execute=true \
  -d ../results/local/benchbase/mysql/baixa
```

## 6. Execução de teste do Vitess

Dentro da pasta do benchbase-mysql
```bash
java -jar benchbase.jar \                       
  -b tpcc \
  -c ../config/tpcc_vitess_baixa.xml \
  --create=true \
  --load=true \
  --execute=true \
  -d ../results/local/benchbase/vitess/baixa
```

## 7. Estrutura de tabelas da configuração `/config/sample_tpcc_config.xml` do BenchBase

```sql
mysql> show tables;
+---------------------+
| Tables_in_benchmark |
+---------------------+
| customer            |
| district            |
| history             |
| item                |
| new_order           |
| oorder              |
| order_line          |
| stock               |
| warehouse           |
+---------------------+
9 rows in set (0.00 sec)
```

# 8. Tabela de mapeamento

| Nível | Sysbench (oltp_read_write)           | BenchBase (TPC-C)                   |
| ----- | ------------------------------------ | ----------------------------------- |
| Baixa | 10 tabelas × 10k linhas, 50 threads  | 1 warehouse, 10 terminais, 60s      |
| Média | 10 tabelas × 100K linhas, 50 threads | 10 warehouses, 50 terminais, 120s   |
| Alta  | 10 tabelas × 1M linhas, 50 threads   | 100 warehouses, 100 terminais, 180s |

## 9. Deve-se deixar claro que:

_“O Sysbench foi utilizado para avaliar operações básicas (CRUD) sob diferentes tamanhos de tabela, enquanto o BenchBase (TPC-C) foi utilizado para simular uma carga transacional mais realista, inspirada em sistemas de comércio.”_

_“Definimos três níveis de carga (baixa, média, alta) variando o scalefactor (número de warehouses) e o número de terminais. Os valores foram ajustados empiricamente para que a carga baixa mantivesse o uso de CPU abaixo de ~30%, a média em um patamar intermediário (~50–70%) e a alta próxima da saturação do sistema, tanto no MySQL quanto no Vitess.”_