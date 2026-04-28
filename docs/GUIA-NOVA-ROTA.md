# Guia: Como Adicionar um Novo Endpoint da API

Tutorial completo para integrar um novo endpoint do Power Embedded ao pipeline. Siga a ordem — cada passo depende do anterior.

---

## Passo 1 — Registrar na tabela de controle

Toda a orquestração parte da tabela `powerembedded_control` no `sqldb_powerembedded_controle`. Antes de qualquer notebook, o endpoint precisa existir aqui com `is_active = 1`.

```sql
INSERT INTO powerembedded_control (
    endpoint,
    endpoint_alias,
    is_paginated,
    load_type,
    delta_param_start,
    delta_param_end,
    last_delta_value,
    run_landing,
    run_ods,
    run_dw,
    is_active,
    concurrency_group
)
VALUES (
    '/api/novo-endpoint',   -- rota relativa, com barra inicial
    'novo_endpoint',        -- alias em snake_case — vira nome do artefato (parquet, tabela ODS)
    1,                      -- 1 se usa paginação por pageNumber, 0 se retorna tudo de uma vez
    'full',                 -- 'full' ou 'incremental_datetime'
    NULL,                   -- nome do param de início (ex: 'startDateTime') — só para incremental
    NULL,                   -- nome do param de fim (ex: 'endDateTime') — só para incremental
    NULL,                   -- último endDateTime — deixar NULL, será atualizado automaticamente
    1,                      -- 1 = ativa extração Landing
    1,                      -- 1 = ativa carga ODS
    0,                      -- 0 = DW ainda não implementado para este endpoint
    1,                      -- 1 = ativo no pipeline
    'normal'                -- 'normal' (concorrência 5) ou 'heavy' (concorrência 2)
);
```

**Explicação de cada campo:**

| Campo | O que preencher |
|-------|----------------|
| `endpoint` | Rota relativa da API conforme documentação do Power Embedded, com `/` inicial |
| `endpoint_alias` | Identificador em snake_case. Vira nome da pasta na Landing (`Files/landing/powerembedded/{alias}/`) e da tabela ODS (`power_embedded_{alias}`) |
| `is_paginated` | `1` se a API usa `pageNumber` e retorna `hasNextPage`. `0` se retorna a resposta completa em uma requisição |
| `load_type` | `full` para dados que podem mudar retroativamente (cadastros, permissões). `incremental_datetime` para eventos imutáveis (logs, auditorias) |
| `delta_param_start` e `delta_param_end` | Apenas para `incremental_datetime`. Consulte a documentação da API para os nomes exatos dos parâmetros |
| `last_delta_value` | Sempre `NULL` ao inserir — o `nb_landing` atualiza automaticamente após cada execução bem-sucedida |
| `run_landing`, `run_ods`, `run_dw` | Controle granular por camada. Use `run_dw = 0` enquanto o notebook DW não estiver implementado |
| `concurrency_group` | Use `heavy` apenas para endpoints com filtro de data que retornam grandes volumes históricos |

---

## Passo 2 — Verificar a Landing

Com o endpoint registrado, rode o `01_nb_landing` manualmente para validar a extração.

**Como executar manualmente no Fabric:**

Abra o notebook `01_nb_landing` e edite a célula de parâmetros temporariamente:

```python
endpoint          = "/api/novo-endpoint"
endpoint_alias    = "novo_endpoint"
is_paginated      = 1
load_type         = "full"
delta_param_start = ""
delta_param_end   = ""
last_delta_value  = ""
```

Execute todas as células. O notebook vai:
1. Buscar a API key do Key Vault
2. Iterar as páginas da API
3. Salvar o Parquet em `Files/landing/powerembedded/novo_endpoint/`
4. Logar o resultado com status e contagem de registros

**Como verificar o Parquet gerado:**

No Fabric, navegue até `lh_bronze > Files > landing > powerembedded > novo_endpoint`. O arquivo `novo_endpoint_{yyyyMMdd_HHmmss}.parquet` deve aparecer. Para inspecionar o conteúdo:

```python
workspace = mssparkutils.env.getWorkspaceName()
path = build_abfss_path(workspace, "lh_bronze", "Files", "landing", "powerembedded", "novo_endpoint")
df = spark.read.parquet(path)
df.printSchema()
df.show(5, truncate=False)
print(f"Total de registros: {df.count()}")
print(f"Colunas: {df.columns}")
```

**O que fazer se retornar vazio:**

Se `nb_landing` encerrar com `status = "empty"`, o endpoint retornou uma lista vazia. Verifique:

1. A rota está correta? Teste diretamente com `curl` ou Postman usando a mesma API key
2. A organização tem dados neste endpoint? Pode ser um endpoint sem histórico ainda
3. Para `incremental_datetime`, o `last_delta_value` inicial pode estar fora do intervalo com dados — ajuste na tabela de controle

---

## Passo 3 — Verificar a ODS

Com o Parquet na Landing, rode o `02_nb_ods` manualmente para validar o processamento.

**Como executar manualmente:**

```python
endpoint_alias = "novo_endpoint"
load_type      = "full"
```

O notebook vai aplicar `flatten_json_columns` e `cast_string_columns` e tentar gravar a tabela Delta `power_embedded_novo_endpoint` em `lh_bronze`.

**Como inspecionar o schema gerado:**

```python
workspace = mssparkutils.env.getWorkspaceName()
path = build_abfss_path(workspace, "lh_bronze", "Tables", "power_embedded", "power_embedded_novo_endpoint")
df_ods = spark.read.format("delta").load(path)
df_ods.printSchema()
df_ods.show(5, truncate=False)
```

**O que fazer se houver colunas JSON aninhadas:**

O `flatten_json_columns` trata isso automaticamente — ele detecta por amostragem e expande campos que contêm `{...}`. Se após a execução ainda houver colunas com conteúdo `{...}`, pode ser que a amostra usada não tenha sido representativa (muitos nulls no início do dataset). Nesse caso:

- Aumente `max_depth` na chamada do flatten (default é 5, raramente necessário mudar)
- Verifique se mais de 50% das amostras da coluna realmente começam com `{`

**O que fazer se o cast inferiou tipo errado:**

O `cast_string_columns` usa amostragem de 50 registros. Se uma coluna mistura tipos (ex: alguns registros têm `"123"` e outros têm `"abc"`), o cast pode falhar ou inferir tipo errado. Verifique:

```python
# Inspecionar valores únicos de uma coluna suspeita
df_ods.select("nome_da_coluna").distinct().show(20, truncate=False)
```

Se o tipo inferido for incompatível com os dados reais, o problema provavelmente está na fonte (API inconsistente). Para forçar um tipo específico, você precisará adicionar lógica de transformação no notebook DW ou fazer um cast explícito.

---

## Passo 4 — Criar tabela DW (para dimensão simples)

Se o novo endpoint mapeia para uma dimensão simples (cadastro com ID único, sem arrays aninhados nem joins complexos), use o notebook genérico `03_nb_dw_dim`.

**Passo 4a — Adicionar entrada no `DIM_CONFIG`**

Abra `03_nb_dw_dim` e localize a CÉLULA 3 (`DIM_CONFIG`). Adicione a configuração da nova dimensão:

```python
DIM_CONFIG = {
    # ... dimensões existentes ...

    "dw_dim_novo_endpoint": {
        "rename": {
            "id":         "sk_novo_endpoint",  # campo id → surrogate key
            "name":       "nm_nome",
            "description": "ds_descricao",
            # adicione todos os campos que devem aparecer na DW
            # campos não listados aqui ficam inalterados (com nome original da ODS)
        },
        "drop": ["dt_extracao"],  # campos a descartar antes do rename
        # dt_carga é sempre descartada internamente — não precisa listar aqui
    },
}
```

**Passo 4b — Adicionar entrada em `_get_dw_list()`**

Abra `nb_helpers` e localize a CÉLULA 7 (`_get_dw_list`). Adicione a nova dimensão na seção de dimensões (antes das bridges):

```python
def _get_dw_list() -> list:
    return [
        # Dimensões existentes...
        {"notebook": "03_nb_dw_dim", "dw_table_name": "dw_dim_novo_endpoint", "source_ods_table": "power_embedded_novo_endpoint", "dependencies": []},

        # Bridges e fatos existentes...
    ]
```

Dimensões não têm dependências — `"dependencies": []`.

**Passo 4c — Rodar manualmente:**

```python
dw_table_name    = "dw_dim_novo_endpoint"
source_ods_table = "power_embedded_novo_endpoint"
```

Execute o `03_nb_dw_dim`. Verifique a tabela gerada:

```python
workspace = mssparkutils.env.getWorkspaceName()
path = build_abfss_path(workspace, "lh_gold", "Tables", "power_embedded", "dw_dim_novo_endpoint")
spark.read.format("delta").load(path).printSchema()
spark.read.format("delta").load(path).show(5, truncate=False)
```

Não se esqueça de atualizar também `run_dw = 1` na tabela de controle para o novo endpoint.

---

## Passo 5 — Criar notebook DW específico (para bridge ou fato)

Se o endpoint requer lógica específica — explode de arrays, joins para enriquecimento, múltiplas fontes ODS — crie um novo notebook seguindo a estrutura dos notebooks existentes.

**Estrutura mínima de um novo notebook de fato:**

```python
# CÉLULA 1 — Parâmetros
if 'dw_table_name'    not in globals(): dw_table_name    = "dw_fact_novo_endpoint"
if 'source_ods_table' not in globals(): source_ods_table = "power_embedded_novo_endpoint"

# CÉLULA 2 — Helpers e Spark
%run 00_nb_helpers
logger = setup_logger("nb_dw_fact_novo_endpoint")
configure_spark_dw()

# CÉLULA 3 — Constantes e caminhos
from pyspark.sql import functions as F
from pyspark.sql.types import TimestampType
from datetime import datetime, timezone

LAKEHOUSE_BRONZE = "lh_bronze"
LAKEHOUSE_GOLD   = "lh_gold"
ODS_SCHEMA = "power_embedded"
DW_SCHEMA  = "power_embedded"

workspace = mssparkutils.env.getWorkspaceName()

ods_table_path = build_abfss_path(workspace, LAKEHOUSE_BRONZE, "Tables", ODS_SCHEMA, source_ods_table)
dw_table_path  = build_abfss_path(workspace, LAKEHOUSE_GOLD,   "Tables", DW_SCHEMA,  dw_table_name)

# CÉLULA 4 — Leitura da ODS
df = spark.read.format("delta").load(ods_table_path)
logger.info(f"{df.count()} registro(s) lidos | {len(df.columns)} coluna(s)")

# CÉLULA 5 — Transformações específicas do fato
# (aplicar taxonomia, descarte de redundâncias, joins com dims, etc.)

# CÉLULA 6 — Deduplicar
before = df.count()
df = df.dropDuplicates(["nk_chave_evento"])  # natural key do evento
after  = df.count()
if before != after:
    logger.info(f"Deduplicação: {before - after} linha(s) removida(s)")

# CÉLULA 7 — Adicionar dt_carga
dt_carga = datetime.now(timezone.utc)
df = df.withColumn("dt_carga", F.lit(dt_carga).cast(TimestampType()))

# CÉLULA 8 — Gravar DW
df.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save(dw_table_path)
row_count = df.count()
logger.info(f"DW gravado: {dw_table_name} | {row_count} linha(s)")

# CÉLULA 9 — Finalização
result = {
    "status":           "success",
    "dw_table_name":    dw_table_name,
    "source_ods_table": source_ods_table,
    "rows":             row_count,
    "columns":          len(df.columns),
}

try:
    log_execucao(logger, "DW", dw_table_name, "success", row_count)
except Exception as e:
    logger.warning(f"Falha ao registrar execução (não crítico): {e}")

mssparkutils.notebook.exit(json.dumps(result))
```

**O que é obrigatório em qualquer notebook worker:**

1. Guards `if ... not in globals()` nos parâmetros (CÉLULA 1)
2. `%run nb_helpers` antes de qualquer código que use funções compartilhadas
3. `log_execucao()` em try/except antes do exit (não-crítico, mas importante para rastreabilidade)
4. `mssparkutils.notebook.exit(json.dumps(result))` — SEMPRE com `json.dumps()`, nunca passando o dict diretamente

**Adicionar em `_get_dw_list()` com dependências:**

```python
# Fatos dependem dos bridges, que dependem das dims
{"notebook": "05_nb_dw_fact_novo_endpoint",
 "dw_table_name": "dw_fact_novo_endpoint",
 "source_ods_table": "power_embedded_novo_endpoint",
 "dependencies": ["dw_bridge_permission"]},  # ajuste conforme as dependências reais
```

O nome em `"notebook"` deve ser exatamente o nome do notebook no Fabric, incluindo o prefixo numérico (ex: `05_nb_dw_fact_novo_endpoint`).

---

## Passo 6 — Testar via orquestrador

Após validar cada camada manualmente, rode o pipeline completo.

**Como disparar o pipeline:**

No Fabric, abra `ppl_powerembedded_orquestrador` e clique em "Run". O pipeline vai:

1. Executar o Lookup Activity para ler todos os endpoints com `is_active = 1`
2. Passar o resultado para o `nb_orquestrador`
3. Executar Landing → ODS → DW em sequência

**Como verificar o resultado:**

Após a execução, consulte a tabela de log:

```sql
SELECT TOP 50
    dt_execucao,
    camada,
    tabela,
    status,
    qtd_registros,
    mensagem_erro
FROM powerembedded_execucoes
WHERE tabela LIKE '%novo_endpoint%'
ORDER BY dt_execucao DESC;
```

Se `status = 'failed'`, a coluna `mensagem_erro` tem o erro capturado. Se `status = 'success'` mas `qtd_registros = NULL`, provavelmente o `log_execucao` não foi chamado corretamente no worker.

**Verificar no pipeline:**

No Fabric, abra o histórico de execução do pipeline. Se uma activity falhou, o `nb_orquestrador` vai ter levantado uma exceção com a mensagem `[DW] Falha nas activities: [nome_da_activity]`.

---

## Armadilhas conhecidas

### `mssparkutils.notebook.exit(dict)` não serializa como JSON

O Fabric serializa um dict Python com `str()` (representação Python com aspas simples), não com JSON. Resultado: `{'status': 'success'}` em vez de `{"status": "success"}`. Qualquer `json.loads()` posterior vai falhar com `JSONDecodeError`.

**Sempre use:**
```python
mssparkutils.notebook.exit(json.dumps(result))
```

### `dbutils` não existe no Fabric

No Databricks, `dbutils.notebook.exit()` é o padrão. No Microsoft Fabric, o equivalente é `mssparkutils`. Usar `dbutils` causa `NameError` em tempo de execução.

**Substitua:**
```python
# ERRADO
dbutils.notebook.exit(json.dumps(result))

# CORRETO
mssparkutils.notebook.exit(json.dumps(result))
```

### Append incremental com schema mismatch (`DELTA_FAILED_TO_MERGE_FIELDS`)

Cenário típico: na primeira carga de um endpoint incremental, uma coluna vem com todos os valores nulos → a ODS grava como `StringType`. Na segunda carga, a coluna tem valores → `cast_string_columns` infere `LongType`. O Delta recusa o append porque o tipo mudou.

**Como prevenir:** o `nb_ods` já inclui schema alignment antes do append (CÉLULA 9). Se o erro ocorrer mesmo assim, verifique se o alinhamento está funcionando — o log deve mostrar linhas como `schema align | nome_coluna: LongType → StringType`.

**Como corrigir após ocorrer:** adicionar `.option("mergeSchema", "true")` no write, ou recriar a tabela com overwrite e reprocessar o histórico incremental.

### Coluna all-null na carga inicial

Se uma coluna vem toda nula na primeira carga, o `cast_string_columns` não tem amostras para inferir o tipo e deixa como `StringType`. Quando a segunda carga trouxer valores, o tipo inferido pode ser diferente. O schema alignment no ODS cuida disso para cargas incrementais, mas para cargas `full` (overwrite) não há problema — o schema é recriado a cada execução.

### Nome do notebook no DAG deve ser o nome exato no Fabric

O campo `"notebook"` em `_get_dw_list()` e nos DAGs de Landing/ODS é o nome exato do notebook no workspace Fabric, incluindo o prefixo numérico. Se o notebook se chama `05_nb_dw_fact_novo_endpoint` no Fabric, use exatamente esse string. Erros de nome resultam em `NotebookNotFound` que só aparece em tempo de execução.

### Nunca use `spark.table()` para leitura cross-lakehouse

O método `spark.table("schema.tabela")` resolve contra o lakehouse **default** configurado no notebook. Quando o notebook é executado via pipeline (`runMultiple`), o lakehouse default pode não ser o esperado — causando `TABLE_OR_VIEW_NOT_FOUND`.

**Regra:** toda leitura de tabela ODS ou DW deve usar ABFSS explícito via `build_abfss_path()`:

```python
# ERRADO — depende do lakehouse default
df = spark.table("power_embedded.dw_dim_user")

# CORRETO — independente de configuração
df = spark.read.format("delta").load(
    build_abfss_path(workspace, LAKEHOUSE_GOLD, "Tables", "power_embedded", "dw_dim_user")
)
```

Isso se aplica especialmente nos notebooks de bridge (`04_nb_dw_bridge_*`), que precisam ler dims do `lh_gold` enquanto a ODS de origem está no `lh_bronze`.

### `log_execucao` falha se a tabela `powerembedded_execucoes` não existir

A função `log_execucao` faz INSERT direto na tabela. Se a tabela não existir no SQL Database, o INSERT vai lançar exceção. Como a chamada está em `try/except`, o notebook não vai derrubar o pipeline — mas o log ficará em branco.

Se a tabela não existir, crie com:

```sql
CREATE TABLE powerembedded_execucoes (
    id                INT IDENTITY(1,1) PRIMARY KEY,
    dt_execucao       DATETIME2       NOT NULL,
    camada            VARCHAR(10)     NOT NULL,
    tabela            VARCHAR(100)    NOT NULL,
    status            VARCHAR(10)     NOT NULL,
    qtd_registros     INT             NULL,
    mensagem_erro     NVARCHAR(MAX)   NULL
);
```

### `last_delta_value` não atualizado em caso de falha na Landing

Para endpoints `incremental_datetime`, o `nb_landing` atualiza `last_delta_value` com o `endDateTime` atual após salvar o Parquet com sucesso. Se o notebook falhar antes desse ponto (ex: erro na extração), `last_delta_value` permanece com o valor anterior e a próxima execução reprocessará o mesmo intervalo — comportamento correto. Mas se falhar após a atualização (ex: erro ao salvar Parquet), o `last_delta_value` avança mas o Parquet não existe. Nesse caso, a ODS vai falhar na próxima execução ao tentar ler um arquivo inexistente. Correção: resetar `last_delta_value` para o valor anterior no SQL Database e re-executar manualmente.

---

**Projeto:** Enterprise / api-embedded
**Versão:** 1.1.0
**Atualizado em:** 2026-04-13

