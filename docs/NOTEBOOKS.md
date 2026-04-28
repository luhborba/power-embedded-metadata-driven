# Documentação de Notebooks — Power Embedded / api-embedded

Documentação célula a célula de todos os notebooks do projeto.

---

## `00_nb_helpers`

**Propósito:** biblioteca de funções compartilhadas. Importado via `%run 00_nb_helpers` por todos os demais notebooks no início de cada execução. Não é chamado diretamente pelo pipeline.

**Parâmetros de entrada (CÉLULA 1):**

| Parâmetro | Padrão | Descrição |
|-----------|--------|-----------|
| `endpoint_list_json` | `"[]"` | JSON com lista de endpoints ativos — sobrescrito pelo pipeline via Lookup Activity quando o orquestrador é chamado |

As constantes `KEY_VAULT_URL`, `DB_SERVER` e `DB_NAME` também ficam na CÉLULA 1 para facilitar manutenção centralizada.

---

### Célula a célula

**CÉLULA 1 — Parâmetros e constantes**
Define `endpoint_list_json` com guard `if 'endpoint_list_json' not in globals()` (padrão para parâmetros Fabric). Define as constantes de conexão: URL do Key Vault, server e nome do Fabric SQL Database.

**CÉLULA 2 — Imports**
Importa `logging`, `json`, `pyodbc` e `datetime`. Mantido separado dos imports específicos de cada função para evitar circular import quando o notebook é rodado via `%run`.

**CÉLULA 3 — `setup_logger()`**
Configura e retorna um logger padrão com formato `timestamp [LEVEL] mensagem`. Idempotente: verifica `logger.handlers` antes de adicionar novo handler, evitando duplicação de logs em notebooks que importam `nb_helpers` múltiplas vezes na mesma sessão Spark.

**CÉLULA 4 — `get_api_key()`**
Recupera a API key do Power Embedded do Key Vault via `notebookutils.credentials.getSecret()`. O nome do secret é `kv-api-powerembedded-token`. Retorna a string da chave para uso no header `X-API-Key`.

**CÉLULA 5 — `get_db_connection()`**
Cria e retorna uma conexão `pyodbc` com o Fabric SQL Database. Usa `Authentication=ActiveDirectoryServicePrincipal` — `client_id` e `client_secret` são obtidos do Key Vault nos secrets `fab-client-id` e `fab-client-secret`. A conexão usa ODBC Driver 18 com TLS obrigatório.

**CÉLULA 6 — `get_pipeline_parameters()`**
Faz `json.loads(endpoint_list_json)` para converter o JSON do Lookup Activity em lista Python. Valida que a lista não está vazia. Chama `_get_dw_list()` internamente. Retorna dict com duas chaves: `endpoint_list` (endpoints ativos) e `dw_list` (tabelas DW configuradas).

**CÉLULA 7 — `_get_dw_list()`**
Retorna a lista hard-coded de tabelas DW com suas dependências. Esta é a fonte de verdade do DAG do DW — qualquer nova tabela DW deve ser adicionada aqui. A ordem no array não importa para execução (o DAG usa `dependencies`), mas por convenção segue a ordem dims → bridges → fatos. O item de `dw_fact_capacity_audit` foi removido porque o endpoint `/api/capacity-audit` retornou vazio em produção.

**CÉLULA 8 — `create_landing_dag()`**
Monta dois DAGs de landing separados por grupo de concorrência (`normal` e `heavy`). Para cada endpoint, cria um objeto `activity` com o caminho `01_nb_landing`, os args do endpoint e timeout/retry. Agrupa por `concurrency_group` da tabela de controle. O orquestrador executa um `runMultiple` para cada grupo — normal primeiro, heavy depois. Grupos sem endpoints retornam DAG com lista de activities vazia (o orquestrador verifica antes de chamar `runMultiple`).

**CÉLULA 9 — `create_ods_dag()`**
Monta DAG ODS com concorrência 5. Todos os endpoints são independentes entre si — sem dependências declaradas. O notebook worker é sempre `02_nb_ods`, diferenciado pelos args `endpoint_alias` e `load_type`.

**CÉLULA 10 — `create_dw_dag()`**
Monta DAG DW a partir da lista retornada por `_get_dw_list()`. Cada item vira uma activity com `path` apontando para o notebook específico (`03_nb_dw_dim`, `04_nb_dw_bridge_*`, `05_nb_dw_fact_*`) e `dependencies` com a lista de `dw_table_name` de que depende. O `runMultiple` do Fabric respeita essas dependências e só executa uma activity após todas as suas dependentes terminarem com sucesso.

**CÉLULA 11 — `records_to_landing_df()`**

```python
def records_to_landing_df(records: list):
```

Converte lista de dicts da API em Spark DataFrame para gravação na Landing. Aplica uma normalização simples: dicts e listas são serializados como JSON string; demais valores são convertidos para string; None permanece None. O schema resultante tem todas as colunas como `StringType`.

Por que todas as colunas como StringType? Três razões:

1. A API pode retornar campos com tipo inconsistente entre páginas ou entre execuções
2. Campos com objetos aninhados (`dict`) ou arrays (`list`) não têm schema previsível sem inspecionar o payload completo
3. O Spark infere colunas com todos os valores nulos como `VOID` — tipo que não pode ser gravado em Parquet sem conversão explícita

Ao serializar tudo para string, a Landing nunca falha por incompatibilidade de tipo. A tipagem correta é responsabilidade da ODS.

**CÉLULA 12 — `build_abfss_path()`**
Constrói o caminho ABFSS completo para leitura/escrita no OneLake. Formato: `abfss://{workspace}@onelake.dfs.fabric.microsoft.com/{lakehouse}.Lakehouse/{layer}/{path_parts}/`. Usado por todos os workers para montar os caminhos de Landing, ODS e DW sem hardcode.

**CÉLULA 13 — `maintenance_delta_table()`**
Executa manutenção em tabela Delta: configura `deletedFileRetentionDuration` e `logRetentionDuration` para 12 horas, roda `OPTIMIZE` (compactação de arquivos pequenos) e `VACUUM` (remoção de arquivos deletados). Reduz o tamanho das tabelas Delta e melhora a performance de leitura via Direct Lake.

**CÉLULA 14 — `flatten_json_columns()` + `cast_string_columns()` (e helpers privados)**

`flatten_json_columns()`:

Expande colunas que contêm JSON objects serializado como string (resultado do `records_to_landing_df`). O processo é:

1. `_detect_json_columns()`: para cada coluna `StringType`, coleta até 20 amostras não-nulas. Se mais de 50% das amostras começam com `{`, tenta inferir o schema via `spark.read.json()`. Se o schema tiver campos, a coluna é candidata ao flatten.
2. Aplica `from_json(col, schema)` para converter a string em StructType.
3. `_expand_structs()`: expande cada campo do struct em coluna plana com nome `pai_filho`. Repete em loop até não restar structs.
4. Todo o processo é iterado até `max_depth=5` ou até não haver mais JSON objects detectados.

JSON arrays (`[...]`) são mantidos como string — tratados no DW quando necessário (ex: explode no bridge de datasets RLS).

`cast_string_columns()`:

Infere e casteia colunas `StringType` remanescentes para tipos nativos. Para cada coluna, coleta até 50 amostras e testa na ordem:

1. **Boolean**: todos os valores são `True/False/true/false`
2. **LongType**: todos os valores passam por `int()` sem erro e sem ponto decimal
3. **DoubleType**: todos os valores passam por `float()` e pelo menos um tem ponto decimal
4. **TimestampType**: todos os valores batem com `\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}`
5. **DateType**: todos os valores batem com `\d{4}-\d{2}-\d{2}`
6. Se nenhum padrão bater, mantém StringType

`skip_cols` (padrão `["dt_extracao", "dt_carga"]`) protege colunas técnicas de serem recasteadas. O cast usa amostragem — se a amostra for homogênea mas o dataset tiver valores mistos, o cast vai falhar em runtime. Por isso o schema alignment no ODS é importante para cargas incrementais.

**CÉLULA 15 — Configurações Spark por camada**

Três funções que ajustam as configurações Spark para cada camada:

- `configure_spark_landing()`: desabilita V-Order (escrita mais rápida para Parquet bruto) e habilita auto-compaction
- `configure_spark_ods()`: habilita V-Order, adaptive execution e optimize write (Delta Silver)
- `configure_spark_dw()`: igual ao ODS — V-Order + optimizeWrite para melhor performance de leitura pelo Direct Lake do Power BI

**CÉLULA 16 — `log_execucao()`**

```python
def log_execucao(logger, camada, tabela, status, rows=None, erro=None):
```

Insere um registro na tabela `powerembedded_execucoes` do SQL Database. Abre uma nova conexão via `get_db_connection()`, executa o INSERT com os parâmetros passados e fecha a conexão.

Por que essa função fica no worker e não no orquestrador? O orquestrador recebe o resultado de cada activity do `runMultiple` via `exitValue` — que pode ser um dict serializado de forma inconsistente pelo Fabric. Registrar o log diretamente no worker, com as variáveis locais disponíveis, é mais confiável e elimina a necessidade de parsear o exitValue no orquestrador.

A chamada em todos os workers é envolta em `try/except` — falha no log é não-crítica (não deve derrubar o pipeline).

**CÉLULA 17 — Confirmação de carregamento**
Instancia o logger e loga `"nb_helpers carregado com sucesso."`. Serve como confirmação visual no output do notebook de que o `%run` terminou sem erros.

---

## `nb_landing` (01_nb_landing)

**Propósito:** worker de extração. Chamado em paralelo pelo orquestrador via `runMultiple`. Cada instância processa um endpoint da API, salva o Parquet na Landing e atualiza o controle incremental.

**Parâmetros de entrada (CÉLULA 1):**

| Parâmetro | Padrão | Descrição |
|-----------|--------|-----------|
| `endpoint` | `""` | Rota relativa da API (ex: `/api/user`) |
| `endpoint_alias` | `""` | Nome do artefato (ex: `user`) |
| `is_paginated` | `1` | `1` = usa paginação por `pageNumber` |
| `load_type` | `"full"` | `full` ou `incremental_datetime` |
| `delta_param_start` | `""` | Nome do parâmetro de início (ex: `startDateTime`) |
| `delta_param_end` | `""` | Nome do parâmetro de fim (ex: `endDateTime`) |
| `last_delta_value` | `""` | `endDateTime` da última execução bem-sucedida |

**Saída (`exitValue`):**
```json
{"status": "success", "endpoint_alias": "user", "records": 142, "file_path": "Files/landing/powerembedded/user/user_20260401_120000.parquet"}
```
ou
```json
{"status": "empty", "endpoint_alias": "user", "records": 0, "file_path": null}
```

---

### Célula a célula

**CÉLULA 1 — Parâmetros**
Define todos os parâmetros com guards `if ... not in globals()`. Padrão obrigatório no Fabric para que a célula funcione tanto em execução manual quanto via `runMultiple`.

**CÉLULA 2 — Imports e helpers**
Executa `%run 00_nb_helpers` para carregar todas as funções compartilhadas. Importa `requests`, `datetime` e tipos Spark. Instancia o logger com nome `"nb_landing"`.

**CÉLULA 3 — Constantes**
Define `BASE_URL = "https://api.powerembedded.com.br"`, `LANDING_BASE = "Files/landing/powerembedded"` e `RETENTION_DAYS = 7`.

**CÉLULA 4 — Validação de parâmetros**
Lança `ValueError` se `endpoint` ou `endpoint_alias` estiverem vazios. Falha cedo com mensagem clara antes de fazer qualquer chamada HTTP.

**CÉLULA 5 — Obter API key**
Chama `get_api_key(logger)` para recuperar a chave do Key Vault. Monta o header `{"X-API-Key": key}` para as requisições.

**CÉLULA 6 — Montar parâmetros de query**
Para `load_type == "incremental_datetime"`: usa `last_delta_value` como `start` (ou `"2024-01-01T00:00:00"` na primeira execução quando `last_delta_value` é vazio). Calcula `end` como `datetime.now(utc)`. Valida que `delta_param_start` e `delta_param_end` estão preenchidos na tabela de controle. Monta `query_params` com os nomes corretos dos parâmetros da API.

Para `load_type == "full"`: `query_params` fica vazio, apenas `pageNumber` é adicionado na paginação.

**CÉLULA 7 — Extração com paginação**
Para endpoints paginados (`is_paginated = 1`): itera páginas incrementando `pageNumber` a partir de 1. Para cada página, faz GET com timeout de 60 segundos, chama `response.raise_for_status()` e acumula `body["data"]` em `all_records`. Interrompe quando `hasNextPage == false`.

Para endpoints não paginados: faz GET único. O corpo da resposta pode ser uma lista direta ou um envelope com `"data"` — o código trata ambos.

**CÉLULA 8 — Verificar se há registros**
Se `all_records` estiver vazio, encerra o notebook com `mssparkutils.notebook.exit(json.dumps({...}))` e status `"empty"`. Não salva arquivo. O `json.dumps()` é obrigatório — passar um dict diretamente faz o Fabric serializar com `str()` Python (aspas simples), quebrando qualquer `json.loads` posterior.

**CÉLULA 9 — Criar DataFrame e adicionar `dt_extracao`**
Chama `records_to_landing_df(all_records)` para criar o DataFrame com todas as colunas como `StringType`. Adiciona a coluna `dt_extracao` com `F.lit(dt_extracao).cast(TimestampType())` — timestamp UTC do momento da extração.

**CÉLULA 10 — Salvar Parquet**
Monta o nome do arquivo: `{alias}_{yyyyMMdd_HHmmss}.parquet`. O caminho relativo no Lakehouse é `Files/landing/powerembedded/{alias}/{alias}_{ts}.parquet`. Grava com `df.write.mode("overwrite").parquet(file_path)`. O modo `overwrite` é seguro aqui porque o nome do arquivo contém o timestamp — nunca sobrescreve um arquivo anterior.

**CÉLULA 11 — Limpeza de retenção**
Lista os arquivos na pasta `Files/landing/powerembedded/{alias}/` via `notebookutils.fs.ls()`. Remove os arquivos com `modifyTime` anterior ao cutoff de 7 dias (calculado em milissegundos). Operação envolta em `try/except` — falha na limpeza é não-crítica.

**CÉLULA 12 — Atualizar `last_delta_value`**
Executado apenas para `load_type == "incremental_datetime"`. Faz `UPDATE powerembedded_control SET last_delta_value = ? WHERE endpoint_alias = ?` via `get_db_connection()`. Registra o `endDateTime` da execução atual para ser usado como `startDateTime` na próxima. Lança exceção se o update falhar — é crítico para manter a cadência incremental correta.

**CÉLULA 13 — Retorno**
Monta `result` dict com `status`, `endpoint_alias`, `records` e `file_path`. Loga e encerra com `mssparkutils.notebook.exit(json.dumps(result))`.

---

## `nb_ods` (02_nb_ods)

**Propósito:** worker ODS. Lê o Parquet mais recente da Landing, aplica flatten de JSON, type casting e schema alignment, e grava na tabela Delta ODS correspondente.

**Parâmetros de entrada (CÉLULA 1):**

| Parâmetro | Padrão | Descrição |
|-----------|--------|-----------|
| `endpoint_alias` | `""` | Alias do endpoint (ex: `user`) |
| `load_type` | `"full"` | `full` ou `incremental_datetime` |

**Saída (`exitValue`):**
```json
{"status": "success", "endpoint_alias": "user", "load_type": "full", "rows": 142, "columns": 28, "ods_table": "power_embedded_user"}
```

---

### Célula a célula

**CÉLULA 1 — Parâmetros**
Guards padrão para `endpoint_alias` e `load_type`.

**CÉLULA 2 — Helpers e configuração Spark**
`%run 00_nb_helpers`, instancia logger `"nb_ods"` e chama `configure_spark_ods()` (V-Order + adaptive execution).

**CÉLULA 3 — Constantes**
Define `LAKEHOUSE = "lh_bronze"`, `ODS_SCHEMA = "power_embedded"` e monta os caminhos `landing_folder` (ABFSS para a pasta Landing do endpoint em `lh_bronze`) e `ods_table_path` (ABFSS para a tabela Delta `power_embedded_{alias}` em `lh_bronze`) via `build_abfss_path()`. Recupera o nome do workspace via `mssparkutils.env.getWorkspaceName()`.

**CÉLULA 4 — Encontrar arquivo mais recente**
Lista arquivos em `landing_folder` via `mssparkutils.fs.ls()`. Filtra por extensão `.parquet`. Seleciona o arquivo com maior `modifyTime` — garante que a carga ODS sempre usa o dado mais recente disponível na Landing.

**CÉLULA 5 — Leitura do Parquet**
`spark.read.parquet(latest_file.path)`. O DataFrame vem com todas as colunas como `StringType` (conforme gravado pela Landing). Loga contagem de linhas e colunas.

**CÉLULA 6 — Flatten recursivo de colunas JSON**
Chama `flatten_json_columns(df, logger, max_depth=5)`. Expande recursivamente campos que contêm JSON objects serializado como string. Loga a contagem de colunas antes e depois do flatten.

**CÉLULA 7 — Type casting**
Chama `cast_string_columns(df, logger, skip_cols=["dt_extracao"])`. Infere e casteia colunas escalares para seus tipos nativos. A coluna `dt_extracao` é explicitamente excluída — já é `TimestampType` e não deve ser recasteada.

**CÉLULA 8 — Adicionar `dt_carga`**
Adiciona `dt_carga` com `datetime.now(timezone.utc)`.

**CÉLULA 9 — Gravar ODS**

Para `load_type == "full"`: grava com `.mode("overwrite").option("overwriteSchema", "true")`. Overwrite completo — o schema pode mudar entre cargas se a API adicionar/remover campos.

Para `load_type == "incremental_datetime"`: antes do append, lê o schema da tabela Delta existente e casteia o novo DataFrame para corresponder exatamente aos tipos já gravados. Isso resolve o caso onde uma coluna era null na carga inicial (ficou como `StringType`) e na carga seguinte o `cast_string_columns` inferiu tipo diferente (ex: `LongType`). O Delta recusa o append quando o tipo muda, mesmo com `mergeSchema=true`. Após o alinhamento, grava com `.mode("append").option("mergeSchema", "true")`.

O `mergeSchema=true` cobre o caso inverso: coluna nova na API que ainda não existe na tabela.

**CÉLULA 10 — Finalização**
Chama `log_execucao(logger, "ODS", ODS_TABLE, "success", row_count)` em `try/except`. Monta `result` dict e encerra com `mssparkutils.notebook.exit(json.dumps(result))`.

---

## `nb_dw_dim` (03_nb_dw_dim)

**Propósito:** worker DW genérico para todas as 5 dimensões. Lê da ODS, aplica a configuração do `DIM_CONFIG` para a dimensão específica (renomear, descartar colunas), deduplica e grava na tabela DW.

**Parâmetros de entrada (CÉLULA 1):**

| Parâmetro | Padrão | Descrição |
|-----------|--------|-----------|
| `dw_table_name` | `""` | Nome da tabela DW (ex: `dw_dim_user`) |
| `source_ods_table` | `""` | Tabela ODS de origem (ex: `power_embedded_user`) |

**Saída (`exitValue`):**
```json
{"status": "success", "dw_table_name": "dw_dim_user", "source_ods_table": "power_embedded_user", "rows": 87, "columns": 29}
```

---

### Célula a célula

**CÉLULA 1 — Parâmetros**
Guards para `dw_table_name` e `source_ods_table`.

**CÉLULA 2 — Helpers e Spark**
`%run 00_nb_helpers`, logger `"nb_dw_dim"`, `configure_spark_dw()`.

**CÉLULA 3 — `DIM_CONFIG`**
Dicionário com a configuração de cada dimensão. Para cada `dw_table_name`, define:
- `rename`: mapeamento `{campo_ods: campo_dw}` com a taxonomia de prefixos
- `drop`: lista de campos a descartar antes do rename

As 5 dimensões configuradas: `dw_dim_dataset`, `dw_dim_report`, `dw_dim_user`, `dw_dim_group`, `dw_dim_folder`.

**CÉLULA 4 — Validar configuração**
Verifica se `dw_table_name` existe no `DIM_CONFIG`. Falha com `ValueError` descritivo se não existir — protege contra typos nos parâmetros. Define `LAKEHOUSE_BRONZE = "lh_bronze"` e `LAKEHOUSE_GOLD = "lh_gold"` e monta os caminhos ABFSS: ODS lido de `lh_bronze`, DW escrito em `lh_gold`.

**CÉLULA 5 — Leitura da ODS**
`spark.read.format("delta").load(ods_table_path)`. Loga contagem.

**CÉLULA 6 — Remover colunas**
Descarta as colunas em `config["drop"]` mais `dt_carga` (que será recriada com o timestamp atual da carga DW). Usa list comprehension com `if c in df.columns` para não quebrar se algum campo não existir.

**CÉLULA 7 — Aplicar taxonomia**
Itera `config["rename"]` e chama `df.withColumnRenamed()` para cada par. Usa guard `if old_name in df.columns` — campos ausentes na ODS são ignorados sem erro.

**CÉLULA 8 — Deduplicar**
`df.dropDuplicates()` geral (sem coluna específica). Loga quantas linhas foram removidas.

**CÉLULA 9 — Adicionar `dt_carga`**
Timestamp UTC atual da carga DW.

**CÉLULA 10 — Gravar DW**
Overwrite com `overwriteSchema=true`. Dimensões são sempre full load — sem incremental.

**CÉLULA 11 — Finalização**
`log_execucao()` em try/except. `mssparkutils.notebook.exit(json.dumps(result))`.

---

## `nb_dw_bridge_permission` (04_nb_dw_bridge_permission)

**Propósito:** resolve o relacionamento N:N entre relatórios e usuários/grupos via permissões RLS. Enriquece a ODS com surrogate keys das dimensões via join por nome.

**Parâmetros de entrada (CÉLULA 1):**

| Parâmetro | Padrão |
|-----------|--------|
| `dw_table_name` | `"dw_bridge_permission"` |
| `source_ods_table` | `"power_embedded_permission_report"` |

---

### Célula a célula

**CÉLULA 1 — Parâmetros** / **CÉLULA 2 — Helpers** / **CÉLULA 3 — Constantes**: padrão dos outros workers DW.

**CÉLULA 4 — Leitura da ODS**
Lê `power_embedded_permission_report` via Delta.

**CÉLULA 5 — Remover colunas técnicas + aplicar taxonomia**
Descarta `dt_extracao` e `dt_carga`. Renomeia campos conforme `RENAME_MAP`. Dois tratamentos adicionais:

1. `rlsByGroup` → `nm_grupo_rls`: remove o prefixo `"Group: "` via `regexp_replace`. Ex: `"Group: # Gestores Regionais PA"` → `"# Gestores Regionais PA"`. Necessário para que o join com `dw_dim_group.nm_grupo` funcione.

2. `permissionDetail` → `nm_role_rls`: remove o prefixo `"Role: "`. Ex: `"Role: Geral"` → `"Geral"`.

**CÉLULA 6 — Enriquecer com surrogate keys**
Realiza três joins left para obter as surrogate keys:

- `dw_dim_user` join por `nm_email` → `sk_user`
- `dw_dim_report` join por `nm_report` + `nm_workspace` → `sk_report` (dois campos para evitar ambiguidade entre workspaces com relatórios de mesmo nome)
- `dw_dim_group` join por `nm_grupo_rls` → `sk_group`

Após cada join, verifica e loga a quantidade de NULLs. `sk_group` NULL é esperado para permissões sem grupo RLS. `sk_user` ou `sk_report` NULL indicam dados a investigar.

**CÉLULA 7 — Deduplicar**
`dropDuplicates()` geral.

**CÉLULA 8 — Adicionar `dt_carga`** / **CÉLULA 9 — Gravar DW** / **CÉLULA 10 — Finalização**: padrão dos outros workers.

---

## `nb_dw_bridge_datasets_rls` (04_nb_dw_bridge_datasets_rls)

**Propósito:** explode os arrays de usuários e grupos por role RLS de dataset em linhas individuais, enriquece com `sk_dataset` via join na dimensão de datasets.

**Parâmetros de entrada (CÉLULA 1):**

| Parâmetro | Padrão |
|-----------|--------|
| `dw_table_name` | `"dw_bridge_datasets_rls"` |
| `source_ods_table` | `"power_embedded_datasets_rls"` |

---

### Célula a célula

**CÉLULA 1 a 3**: padrão.

**CÉLULA 4 — Leitura da ODS**
Lê `power_embedded_datasets_rls`. Cada linha é uma role RLS com arrays de usuários e grupos.

**CÉLULA 5 — Taxonomia base**
Descarta `dt_extracao`, `dt_carga` e `userEmails` (redundante com `users`). Renomeia `id` → `nk_role_rls`, `name` → `nm_role_rls`, `datasetId` → `nk_dataset_pbi`.

**CÉLULA 6 — Explodir arrays**
Cria dois DataFrames separados:

- `df_users`: aplica `from_json(users, ArrayType(StringType()))` + `explode_outer(users)` → cada GUID de usuário vira uma linha com `sk_user = guid`, `cd_tipo_membro = "User"`, `sk_group = null`
- `df_groups`: aplica o mesmo para `groups` → `sk_group = guid`, `cd_tipo_membro = "Group"`, `sk_user = null`

Faz `unionByName` dos dois e remove linhas onde ambos `sk_user` e `sk_group` são null (roles vazias).

Por que os GUIDs de usuário e grupo da API coincidem diretamente com `sk_user` e `sk_group` das dims? A API usa o GUID interno do Power Embedded como identificador de usuário e grupo, e as dimensões usam esse mesmo GUID como surrogate key (o campo `id` da ODS virou `sk_user`/`sk_group` na DW). Portanto, não é necessário join adicional — os IDs já são compatíveis.

**CÉLULA 7 — Enriquecer com `sk_dataset`**
`datasetId` da ODS é o GUID do Power BI, não o ID interno do Power Embedded. Por isso precisa de join com `dw_dim_dataset.nk_dataset_pbi` para obter o `sk_dataset` correto.

**CÉLULA 8 — Deduplicar** / **CÉLULA 9 — Adicionar `dt_carga`** / **CÉLULA 10 — Gravar DW** / **CÉLULA 11 — Finalização**: padrão.

---

## `nb_dw_fact_report_audit` (05_nb_dw_fact_report_audit)

**Propósito:** processa eventos de acesso a relatórios. Aplica taxonomia, descarta campos redundantes e verifica cobertura referencial das FKs.

**Parâmetros de entrada (CÉLULA 1):** `dw_table_name` = `"dw_fact_report_audit"`, `source_ods_table` = `"power_embedded_report_audit"`.

---

### Célula a célula

**CÉLULA 1 a 3**: padrão.

**CÉLULA 4 — Leitura da ODS**: lê `power_embedded_report_audit`.

**CÉLULA 5 — Taxonomia + remoção de redundâncias**
Descarta `dt_extracao`, `dt_carga`, `userEmail` e `reportName` — disponíveis via join analítico nas dims no Power BI. Aplica rename conforme `RENAME_MAP`: `id` → `nk_evento`, `userId` → `fk_user`, `reportId` → `fk_report`, etc.

**CÉLULA 6 — Verificar cobertura referencial**
Conta NULLs em `fk_user` e `fk_report`. Nenhum join é feito — os GUIDs da API já são os surrogate keys corretos das dims. NULL aqui significa que o campo veio nulo da ODS — situação rara que deve ser investigada.

**CÉLULA 7 — Deduplicar por `nk_evento`**
`dropDuplicates(["nk_evento"])` — garante que cada evento de auditoria aparece uma única vez, mesmo que a API retorne duplicatas.

**CÉLULA 8 — Adicionar `dt_carga`** / **CÉLULA 9 — Gravar DW** / **CÉLULA 10 — Finalização**: padrão.

---

## `nb_dw_fact_email_audit` (05_nb_dw_fact_email_audit)

**Propósito:** processa eventos de envio de e-mail. Fato isolado — sem FKs para dimensões.

**Parâmetros de entrada (CÉLULA 1):** `dw_table_name` = `"dw_fact_email_audit"`, `source_ods_table` = `"power_embedded_email_audit"`.

---

### Célula a célula

**CÉLULA 1 a 3**: padrão.

**CÉLULA 4 — Leitura da ODS**: lê `power_embedded_email_audit`.

**CÉLULA 5 — Aplicar taxonomia**
Descarta `dt_extracao` e `dt_carga`. Renomeia todos os campos conforme `RENAME_MAP`. Campos notáveis: `status` → `cd_status`, `error` → `ds_erro`. Sem campos redundantes a descartar (fato isolado, sem dims associadas).

**CÉLULA 6 — Deduplicar por `nk_email_audit`**

**CÉLULA 7 — Adicionar `dt_carga`** / **CÉLULA 8 — Gravar DW** / **CÉLULA 9 — Finalização**: padrão.

---

## `nb_dw_fact_identity_audit` (05_nb_dw_fact_identity_audit)

**Propósito:** processa eventos de autenticação. Tem FK para `dw_dim_user` via GUID direto.

**Parâmetros de entrada (CÉLULA 1):** `dw_table_name` = `"dw_fact_identity_audit"`, `source_ods_table` = `"power_embedded_identity_audit"`.

---

### Célula a célula

**CÉLULA 1 a 3**: padrão.

**CÉLULA 4 — Leitura da ODS**: lê `power_embedded_identity_audit`.

**CÉLULA 5 — Taxonomia + remoção de redundâncias**
Descarta `dt_extracao`, `dt_carga` e `userEmail`. Renomeia: `userId` → `fk_user`, `status` → `fl_status`, `signInMode` → `cd_modo_login`, `errorDescriptionType` → `cd_tipo_erro`.

**CÉLULA 6 — Verificar cobertura referencial**
Conta NULLs em `fk_user`.

**CÉLULA 7 — Deduplicar por `nk_identity_audit`**

**CÉLULA 8 — Adicionar `dt_carga`** / **CÉLULA 9 — Gravar DW** / **CÉLULA 10 — Finalização**: padrão.

---

## `nb_orquestrador`

**Propósito:** coordenador central. Chamado pelo pipeline via Notebook Activity. Recebe a lista de endpoints, monta os DAGs e executa as três fases em sequência.

**Parâmetros de entrada (CÉLULA 1):**

| Parâmetro | Padrão | Descrição |
|-----------|--------|-----------|
| `endpoint_list_json` | `"[]"` | JSON com lista de endpoints ativos, vindo do Lookup Activity |

**Saída (`exitValue`):**
```json
{"status": "success", "endpoints_landing": 11, "endpoints_ods": 11, "tables_dw": 10}
```

---

### Célula a célula

**CÉLULA 1 — Parâmetros**
Guard para `endpoint_list_json`. Na execução real, é sobrescrito pelo Lookup Activity do pipeline com o resultado de `SELECT * FROM powerembedded_control WHERE is_active = 1`.

**CÉLULA 2 — Imports e helpers**
`%run 00_nb_helpers`. Instancia logger `"nb_orquestrador"`. Não chama nenhum `configure_spark_*` — o orquestrador não processa dados diretamente.

**CÉLULA 3 — Carregar parâmetros**
Chama `get_pipeline_parameters(logger)` que faz `json.loads(endpoint_list_json)` e valida a lista. Retorna `params["endpoint_list"]` e `params["dw_list"]`.

**CÉLULA 4 — Landing (normal e heavy)**
Define `concurrency_map = {"normal": 5, "heavy": 2}`. Chama `create_landing_dag()` que retorna dois DAGs separados. Define a função auxiliar `_check_failures()` que verifica se alguma activity retornou `exitCode != "0"` — lança exceção com a lista de activities falhas se sim.

Executa Landing normal se houver endpoints nesse grupo, checa falhas, loga conclusão. Repete para heavy. Se um grupo não tiver endpoints, pula o `runMultiple`.

**CÉLULA 5 — ODS**
Monta `dag_ods` via `create_ods_dag()`. Executa `runMultiple` com tratamento de exceção — o `runMultiple` lança exceção quando alguma activity falha, mas ainda retorna os resultados parciais em `e.result`. O código captura a exceção, extrai `e.result` se disponível e chama `_check_failures()` para propagar o erro de forma controlada.

**CÉLULA 6 — DW**
Mesmo padrão do ODS. Monta `dag_dw` via `create_dw_dag()`. O `runMultiple` com dependências garante a ordem dims → bridges → fatos internamente — o orquestrador não precisa controlar essa ordem explicitamente.

**CÉLULA 7 — Encerramento**
Monta `result` com contagens e encerra. Nota: o orquestrador usa `mssparkutils.notebook.exit(result)` sem `json.dumps()` — isso é um ponto a corrigir (ver CHECKPOINT.md), mas como o pipeline apenas verifica o `exitCode` do orquestrador e não parseia seu `exitValue`, não causa problema funcional imediato.

---

**Projeto:** Enterprise / api-embedded
**Versão:** 1.1.0
**Atualizado em:** 2026-04-13

