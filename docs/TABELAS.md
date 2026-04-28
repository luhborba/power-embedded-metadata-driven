# Catálogo de Tabelas — Power Embedded / api-embedded

Documentação de todas as tabelas ODS e DW do projeto, incluindo contexto de uso e exemplos de insights analíticos.

---

## Convenções

- **ODS (Silver):** Delta Lake em `lh_bronze / Tables / power_embedded / power_embedded_{alias}`. Dado limpo e tipado, flatten de JSON aplicado. Preserva os nomes originais da API.
- **DW (Gold):** Delta Lake em `lh_gold / Tables / power_embedded / dw_{dim|bridge|fact}_*`. Taxonomia de nomes padronizada com prefixos (`sk_`, `nk_`, `fk_`, `nm_`, `ds_`, `cd_`, `fl_`, `dt_`, `url_`).
- **load_type full:** overwrite completo a cada execução.
- **load_type incremental_datetime:** append de novos registros, com schema alignment antes do append.

---

## Tabelas ODS

> As tabelas ODS são a camada Silver do pipeline. Servem como fonte para a camada DW e como área de investigação quando há dúvidas sobre o dado bruto da API. Não são usadas diretamente no Power BI.

---

### `power_embedded_datasets`

| Campo | Fonte API | Tipo inferido | Descrição |
|-------|-----------|---------------|-----------|
| `id` | `id` | StringType | ID interno do dataset no Power Embedded |
| `organizationId` | `organizationId` | StringType | ID da organização |
| `workspaceId` | `workspaceId` | StringType | ID do workspace Power BI |
| `datasetId` | `datasetId` | StringType | ID do dataset no Power BI (GUID) |
| `datasetName` | `datasetName` | StringType | Nome do dataset |
| `requiresEffectiveIdentity` | `requiresEffectiveIdentity` | BooleanType | Requer identidade efetiva (RLS dinâmico) |
| `requiresEffectiveIdentityRoles` | `requiresEffectiveIdentityRoles` | BooleanType | Requer roles de identidade efetiva |
| `requiresOnPremisesGateway` | `requiresOnPremisesGateway` | BooleanType | Requer gateway on-premises |
| `selectedRls` | `selectedRls` | StringType | Configuração de RLS selecionada |
| `dt_extracao` | — | TimestampType | Timestamp UTC da extração da API |
| `dt_carga` | — | TimestampType | Timestamp UTC da gravação na ODS |

- **Fonte:** endpoint `/api/datasets`
- **load_type:** `full`
- **Contexto de uso:** Base para `dw_dim_dataset`. Contém metadados de todos os datasets publicados no Power Embedded — usados para rastrear quais datasets têm RLS configurado, quais dependem de gateway on-premises e como os relatórios se relacionam com suas fontes de dados.

---

### `power_embedded_report`

| Campo | Fonte API | Tipo inferido | Descrição |
|-------|-----------|---------------|-----------|
| `id` | `id` | StringType | ID do relatório no Power Embedded |
| `name` | `name` | StringType | Nome do relatório |
| `description` | `description` | StringType | Descrição |
| `datasetId` | `datasetId` | StringType | ID do dataset associado |
| `embedUrl` | `embedUrl` | StringType | URL de embed do relatório |
| `workspaceId` | `workspaceId` | StringType | ID do workspace |
| `reportType` | `reportType` | StringType | Tipo do relatório |
| `folderId` | `folderId` | StringType | ID da pasta onde está alocado |
| `workspaceName` | `workspaceName` | StringType | Nome do workspace |
| `userOwner` | `userOwner` | StringType | E-mail do proprietário |
| `dt_extracao` | — | TimestampType | Timestamp UTC da extração |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga ODS |

- **Fonte:** endpoint `/api/report`
- **load_type:** `full`
- **Contexto de uso:** Base para `dw_dim_report`. Catálogo completo de relatórios disponíveis na plataforma. Permite rastrear distribuição de relatórios por workspace, pasta e proprietário.

---

### `power_embedded_user`

| Campo | Fonte API | Tipo inferido | Descrição |
|-------|-----------|---------------|-----------|
| `id` | `id` | StringType | ID do usuário no Power Embedded |
| `email` | `email` | StringType | E-mail do usuário |
| `name` | `name` | StringType | Nome completo |
| `role` | `role` | StringType | Perfil/papel do usuário |
| `reportLandingPage` | `reportLandingPage` | StringType | Página inicial configurada |
| `department` | `department` | StringType | Departamento |
| `expirationDate` | `expirationDate` | TimestampType/DateType | Data de expiração do acesso |
| `windowsAdUser` | `windowsAdUser` | StringType | Usuário no Active Directory |
| `canEditReport` | `canEditReport` | BooleanType | Permissão de edição de relatório |
| `canCreateReport` | `canCreateReport` | BooleanType | Permissão de criação de relatório |
| `canOverwriteReport` | `canOverwriteReport` | BooleanType | Permissão de sobrescrever relatório |
| `canRefreshDataset` | `canRefreshDataset` | BooleanType | Permissão de atualizar dataset |
| `canCreateSubscription` | `canCreateSubscription` | BooleanType | Permissão de criar assinatura |
| `canDownloadPbix` | `canDownloadPbix` | BooleanType | Permissão de baixar .pbix |
| `canExportReport` | `canExportReport` | BooleanType | Permissão de exportar relatório |
| `canExportReportWithHiddenPages` | `canExportReportWithHiddenPages` | BooleanType | Permissão de exportar com páginas ocultas |
| `hideHomePages` | `hideHomePages` | BooleanType | Ocultar página inicial |
| `hideAddressBook` | `hideAddressBook` | BooleanType | Ocultar lista de contatos |
| `hideFavorites` | `hideFavorites` | BooleanType | Ocultar favoritos |
| `hideMostAccessed` | `hideMostAccessed` | BooleanType | Ocultar mais acessados |
| `hideRecentlyAccessed` | `hideRecentlyAccessed` | BooleanType | Ocultar recentes |
| `hideRecentlyPublished` | `hideRecentlyPublished` | BooleanType | Ocultar publicados recentemente |
| `hideFolders` | `hideFolders` | BooleanType | Ocultar pastas |
| `canCreateNewUsers` | `canCreateNewUsers` | BooleanType | Permissão de criar novos usuários |
| `canStartCapacityByDemand` | `canStartCapacityByDemand` | BooleanType | Permissão de iniciar capacidade sob demanda |
| `canDisplayVisualHeaders` | `canDisplayVisualHeaders` | BooleanType | Permissão de exibir cabeçalhos de visuais |
| `accessReportAnyTime` | `accessReportAnyTime` | BooleanType | Acesso ao relatório em qualquer horário |
| `reports` | `reports` | StringType (JSON array) | Array de relatórios — descartado na DW |
| `companies` | `companies` | StringType (JSON array) | Array de empresas — descartado na DW |
| `groups` | `groups` | StringType (JSON array) | Array de grupos — descartado na DW |
| `reportNames` | `reportNames` | StringType (JSON array) | Nomes de relatórios — descartado na DW |
| `dt_extracao` | — | TimestampType | Timestamp UTC da extração |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga ODS |

- **Fonte:** endpoint `/api/user`
- **load_type:** `full`
- **Contexto de uso:** Base para `dw_dim_user`. Cada usuário cadastrado no Power Embedded com todos os seus atributos de permissão granular. Campos `reports`, `companies`, `groups`, `reportNames` são arrays descartados na DW — a informação de relacionamento existe nas tabelas de bridge.

---

### `power_embedded_groups`

| Campo | Fonte API | Tipo inferido | Descrição |
|-------|-----------|---------------|-----------|
| `id` | `id` | StringType | ID do grupo no Power Embedded |
| `organizationId` | `organizationId` | StringType | ID da organização |
| `name` | `name` | StringType | Nome do grupo |
| `description` | `description` | StringType | Descrição do grupo |
| `canEditReport` | `canEditReport` | BooleanType | Permissão de edição de relatório |
| `canCreateReport` | `canCreateReport` | BooleanType | Permissão de criação de relatório |
| `canOverwriteReport` | `canOverwriteReport` | BooleanType | Permissão de sobrescrever relatório |
| `canRefreshDataset` | `canRefreshDataset` | BooleanType | Permissão de atualizar dataset |
| `bypassFirewall` | `bypassFirewall` | BooleanType | Ignora restrições de firewall |
| `reports` | `reports` | StringType (JSON array) | Relatórios associados — descartado na DW |
| `users` | `users` | StringType (JSON array) | Usuários do grupo — descartado na DW |
| `dt_extracao` | — | TimestampType | Timestamp UTC da extração |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga ODS |

- **Fonte:** endpoint `/api/groups`
- **load_type:** `full`
- **Contexto de uso:** Base para `dw_dim_group`. Grupos são a unidade de controle de acesso do Power Embedded — um usuário pertence a um grupo e herda as permissões RLS do grupo nos relatórios.

---

### `power_embedded_folders`

| Campo | Fonte API | Tipo inferido | Descrição |
|-------|-----------|---------------|-----------|
| `id` | `id` | StringType | ID da pasta |
| `organizationId` | `organizationId` | StringType | ID da organização |
| `name` | `name` | StringType | Nome da pasta |
| `parentFolderId` | `parentFolderId` | StringType | ID da pasta pai (null = raiz) |
| `dt_extracao` | — | TimestampType | Timestamp UTC da extração |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga ODS |

- **Fonte:** endpoint `/api/folders` (não paginado)
- **load_type:** `full`
- **Contexto de uso:** Base para `dw_dim_folder`. Estrutura hierárquica de organização dos relatórios — pastas podem conter subpastas (`parentFolderId` aponta para outra pasta).

---

### `power_embedded_datasets_rls`

| Campo | Fonte API | Tipo inferido | Descrição |
|-------|-----------|---------------|-----------|
| `id` | `id` | StringType | ID da role RLS |
| `name` | `name` | StringType | Nome da role RLS |
| `users` | `users` | StringType (JSON array de GUIDs) | GUIDs dos usuários com essa role |
| `groups` | `groups` | StringType (JSON array de GUIDs) | GUIDs dos grupos com essa role |
| `datasetId` | `datasetId` | StringType | GUID do dataset (Power BI ID) |
| `userEmails` | `userEmails` | StringType (JSON array) | E-mails redundantes — descartado na DW |
| `dt_extracao` | — | TimestampType | Timestamp UTC da extração |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga ODS |

- **Fonte:** endpoint `/api/datasets/rls`
- **load_type:** `full`
- **Contexto de uso:** Base para `dw_bridge_datasets_rls`. Define quais usuários e grupos têm quais roles RLS em cada dataset — controle de segurança em nível de dado (linha por linha).

---

### `power_embedded_permission_report`

| Campo | Fonte API | Tipo inferido | Descrição |
|-------|-----------|---------------|-----------|
| `organizationId` | `organizationId` | StringType | ID da organização |
| `type` | `type` | StringType | Tipo de permissão (ex: `GroupRlsPermission`) |
| `userEmail` | `userEmail` | StringType | E-mail do usuário com a permissão |
| `reportName` | `reportName` | StringType | Nome do relatório |
| `workspaceName` | `workspaceName` | StringType | Nome do workspace |
| `permissionDetail` | `permissionDetail` | StringType | Detalhe da permissão (ex: `Role: Geral`) |
| `rlsByGroup` | `rlsByGroup` | StringType | Grupo RLS (ex: `Group: # Gestores Regionais PA`) |
| `dt_extracao` | — | TimestampType | Timestamp UTC da extração |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga ODS |

- **Fonte:** endpoint `/api/permission-report`
- **load_type:** `full`
- **Contexto de uso:** Base para `dw_bridge_permission`. Tabela desnormalizada que já vem da API com o cruzamento usuário × relatório × grupo RLS × role — não exige explosão de arrays. É a principal fonte para análises de "quem pode ver o quê".

---

### `power_embedded_report_audit`

| Campo | Fonte API | Tipo inferido | Descrição |
|-------|-----------|---------------|-----------|
| `id` | `id` | StringType | ID único do evento de auditoria |
| `createdAt` | `createdAt` | TimestampType | Timestamp do evento |
| `organizationId` | `organizationId` | StringType | ID da organização |
| `userId` | `userId` | StringType | GUID do usuário (= `sk_user` na DW dim) |
| `userEmail` | `userEmail` | StringType | E-mail redundante — descartado na DW |
| `reportId` | `reportId` | StringType | GUID do relatório (= `sk_report` na DW dim) |
| `reportName` | `reportName` | StringType | Nome redundante — descartado na DW |
| `action` | `action` | LongType | Código numérico da ação |
| `actionName` | `actionName` | StringType | Descrição da ação |
| `dt_extracao` | — | TimestampType | Timestamp UTC da extração |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga ODS |

- **Fonte:** endpoint `/api/report-audit`
- **load_type:** `full`
- **Contexto de uso:** Base para `dw_fact_report_audit`. Cada linha é um evento de acesso ou interação de um usuário em um relatório. É a principal fonte para análises de engajamento, uso e adoção da plataforma.

---

### `power_embedded_email_audit`

| Campo | Fonte API | Tipo inferido | Descrição |
|-------|-----------|---------------|-----------|
| `id` | `id` | StringType | ID único do evento de e-mail |
| `organizationId` | `organizationId` | StringType | ID da organização |
| `createdAt` | `createdAt` | TimestampType | Timestamp do envio |
| `templateName` | `templateName` | StringType | Nome do template de e-mail |
| `subject` | `subject` | StringType | Assunto do e-mail |
| `companyName` | `companyName` | StringType | Nome da empresa destinatária |
| `destination` | `destination` | StringType | Endereço de destino |
| `smtpHost` | `smtpHost` | StringType | Servidor SMTP utilizado |
| `status` | `status` | StringType/LongType | Código de status do envio |
| `error` | `error` | StringType | Mensagem de erro (null se sucesso) |
| `dt_extracao` | — | TimestampType | Timestamp UTC da extração |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga ODS |

- **Fonte:** endpoint `/api/email-audit`
- **load_type:** `full`
- **Contexto de uso:** Base para `dw_fact_email_audit`. Rastreia todos os e-mails enviados pela plataforma — notificações, alertas de refresh, convites. Útil para identificar falhas de entrega e volume de comunicação por empresa.

---

### `power_embedded_identity_audit`

| Campo | Fonte API | Tipo inferido | Descrição |
|-------|-----------|---------------|-----------|
| `id` | `id` | StringType | ID único do evento de autenticação |
| `timeStamp` | `timeStamp` | TimestampType | Timestamp do evento |
| `organizationId` | `organizationId` | StringType | ID da organização |
| `userId` | `userId` | StringType | GUID do usuário |
| `actionType` | `actionType` | LongType | Código numérico do tipo de ação |
| `userEmail` | `userEmail` | StringType | E-mail redundante — descartado na DW |
| `userAgent` | `userAgent` | StringType | Browser/client utilizado |
| `ipAddress` | `ipAddress` | StringType | Endereço IP de origem |
| `status` | `status` | BooleanType | `true` = sucesso, `false` = falha |
| `signInMode` | `signInMode` | LongType | Código do modo de autenticação |
| `errorDescriptionType` | `errorDescriptionType` | StringType/LongType | Código do tipo de erro (0 = sem erro) |
| `dt_extracao` | — | TimestampType | Timestamp UTC da extração |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga ODS |

- **Fonte:** endpoint `/api/identity-audit`
- **load_type:** `incremental_datetime`
- **Contexto de uso:** Base para `dw_fact_identity_audit`. Cada linha é um evento de login ou autenticação. Único endpoint incremental do projeto — acumula histórico de acessos ao longo do tempo.
- **Atenção:** `errorDescriptionType` pode vir como `StringType` na primeira carga (valores nulos) e como `LongType` nas cargas seguintes. O schema alignment no `nb_ods` CÉLULA 9 resolve isso automaticamente.

---

### `power_embedded_datasets_refresh_history`

| Campo | Fonte API | Tipo inferido | Descrição |
|-------|-----------|---------------|-----------|
| (campos do endpoint `/api/datasets/refresh-history`) | — | Varia | Histórico de atualizações de datasets |
| `dt_extracao` | — | TimestampType | Timestamp UTC da extração |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga ODS |

- **Fonte:** endpoint `/api/datasets/refresh-history`
- **load_type:** `full`
- **Contexto de uso:** Histórico de execuções de refresh de datasets. Permite identificar falhas recorrentes, horários de atualização e datasets com refresh instável. Schema completo a confirmar após primeira carga em produção com dados.

---

### `power_embedded_report_access_requests`

| Campo | Fonte API | Tipo inferido | Descrição |
|-------|-----------|---------------|-----------|
| (campos do endpoint `/api/report-access-requests`) | — | Varia | Solicitações de acesso a relatórios |
| `dt_extracao` | — | TimestampType | Timestamp UTC da extração |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga ODS |

- **Fonte:** endpoint `/api/report-access-requests`
- **load_type:** `full`
- **Contexto de uso:** Registra quando usuários solicitam acesso a relatórios que ainda não têm permissão. Útil para priorizar concessões de acesso e identificar relatórios com alta demanda reprimida. Sem tabela DW correspondente por enquanto.

---

## Tabelas DW — Dimensões

> As dimensões são as entidades do modelo. Todas usam overwrite completo (full load) — refletem sempre o estado atual da plataforma.

---

### `dw_dim_dataset`

- **Fonte ODS:** `power_embedded_datasets`
- **Tipo:** Dimensão
- **load_type:** `full` (overwrite)
- **Notebook:** `03_nb_dw_dim`

| Campo DW | Campo ODS | Tipo | Descrição |
|----------|-----------|------|-----------|
| `sk_dataset` | `id` | StringType | Surrogate key do dataset |
| `cd_organizacao` | `organizationId` | StringType | Código da organização |
| `cd_workspace` | `workspaceId` | StringType | ID do workspace Power BI |
| `nk_dataset_pbi` | `datasetId` | StringType | Natural key — GUID do dataset no Power BI |
| `nm_dataset` | `datasetName` | StringType | Nome do dataset |
| `fl_requer_identidade_efetiva` | `requiresEffectiveIdentity` | BooleanType | Requer RLS dinâmico |
| `fl_requer_roles_identidade` | `requiresEffectiveIdentityRoles` | BooleanType | Requer roles de identidade |
| `fl_requer_gateway_on_prem` | `requiresOnPremisesGateway` | BooleanType | Requer gateway on-premises |
| `ds_rls_selecionado` | `selectedRls` | StringType | Configuração RLS selecionada |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga DW |

- **Descartado da ODS:** `dt_extracao`, `dt_carga` (recriado no DW)
- **Deduplicação:** `dropDuplicates()` geral
- **Contexto de uso:** Dimensão central para análises de RLS e cobertura de segurança. O `nk_dataset_pbi` é a chave de join com relatórios — um relatório referencia o dataset pelo GUID do Power BI, não pelo ID interno do Power Embedded.

**Exemplos de insights:**
```sql
-- Datasets que exigem RLS dinâmico (requerem identidade efetiva)
SELECT nm_dataset, cd_workspace
FROM dw_dim_dataset
WHERE fl_requer_identidade_efetiva = true

-- Datasets dependentes de gateway on-premises (risco de indisponibilidade)
SELECT nm_dataset, cd_workspace
FROM dw_dim_dataset
WHERE fl_requer_gateway_on_prem = true
ORDER BY nm_dataset
```

---

### `dw_dim_report`

- **Fonte ODS:** `power_embedded_report`
- **Tipo:** Dimensão
- **load_type:** `full` (overwrite)
- **Notebook:** `03_nb_dw_dim`

| Campo DW | Campo ODS | Tipo | Descrição |
|----------|-----------|------|-----------|
| `sk_report` | `id` | StringType | Surrogate key do relatório |
| `nm_report` | `name` | StringType | Nome do relatório |
| `ds_report` | `description` | StringType | Descrição |
| `fk_dataset` | `datasetId` | StringType | FK para `dw_dim_dataset.sk_dataset` via `nk_dataset_pbi` |
| `url_embed` | `embedUrl` | StringType | URL de embed |
| `cd_workspace` | `workspaceId` | StringType | ID do workspace |
| `cd_tipo_report` | `reportType` | StringType | Tipo do relatório |
| `fk_folder` | `folderId` | StringType | FK para `dw_dim_folder.sk_folder` |
| `nm_workspace` | `workspaceName` | StringType | Nome do workspace |
| `nm_usuario_proprietario` | `userOwner` | StringType | E-mail do proprietário |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga DW |

- **Obs:** `fk_dataset` referencia `dw_dim_dataset.sk_dataset` indiretamente — o `datasetId` do relatório corresponde ao `nk_dataset_pbi` da dimensão de dataset
- **Contexto de uso:** Catálogo analítico de todos os relatórios publicados. Permite cruzar acessos (fato) com metadados de relatório — saber quais relatórios são mais acessados, quem os criou e em qual pasta estão.

**Exemplos de insights:**
```sql
-- Relatórios sem proprietário definido (risco de abandono)
SELECT nm_report, nm_workspace
FROM dw_dim_report
WHERE nm_usuario_proprietario IS NULL

-- Distribuição de relatórios por workspace
SELECT nm_workspace, COUNT(*) AS qtd_reports
FROM dw_dim_report
GROUP BY nm_workspace
ORDER BY qtd_reports DESC

-- Relatórios por pasta (join com dw_dim_folder)
SELECT f.nm_pasta, COUNT(r.sk_report) AS qtd_reports
FROM dw_dim_report r
LEFT JOIN dw_dim_folder f ON r.fk_folder = f.sk_folder
GROUP BY f.nm_pasta
```

---

### `dw_dim_user`

- **Fonte ODS:** `power_embedded_user`
- **Tipo:** Dimensão
- **load_type:** `full` (overwrite)
- **Notebook:** `03_nb_dw_dim`

| Campo DW | Campo ODS | Tipo | Descrição |
|----------|-----------|------|-----------|
| `sk_user` | `id` | StringType | Surrogate key do usuário |
| `nm_email` | `email` | StringType | E-mail (usado como chave de join em bridges e fatos) |
| `nm_usuario` | `name` | StringType | Nome completo |
| `cd_perfil` | `role` | StringType | Perfil/papel do usuário |
| `ds_pagina_inicial` | `reportLandingPage` | StringType | Página inicial configurada |
| `nm_departamento` | `department` | StringType | Departamento |
| `dt_expiracao` | `expirationDate` | TimestampType/DateType | Data de expiração do acesso |
| `nm_usuario_ad` | `windowsAdUser` | StringType | Usuário no AD |
| `fl_pode_editar_report` | `canEditReport` | BooleanType | Permissão de edição |
| `fl_pode_criar_report` | `canCreateReport` | BooleanType | Permissão de criação |
| `fl_pode_sobrescrever_report` | `canOverwriteReport` | BooleanType | Permissão de sobrescrita |
| `fl_pode_atualizar_dataset` | `canRefreshDataset` | BooleanType | Permissão de refresh |
| `fl_pode_criar_assinatura` | `canCreateSubscription` | BooleanType | Permissão de assinatura |
| `fl_pode_baixar_pbix` | `canDownloadPbix` | BooleanType | Permissão de download .pbix |
| `fl_pode_exportar_report` | `canExportReport` | BooleanType | Permissão de exportação |
| `fl_pode_exportar_paginas_ocultas` | `canExportReportWithHiddenPages` | BooleanType | Exportar com páginas ocultas |
| `fl_ocultar_pagina_inicial` ... `fl_ocultar_pastas` | (vários) | BooleanType | Configurações de UI ocultas |
| `fl_pode_criar_usuarios` | `canCreateNewUsers` | BooleanType | Permissão de criar usuários |
| `fl_pode_iniciar_capacidade` | `canStartCapacityByDemand` | BooleanType | Iniciar capacidade sob demanda |
| `fl_acesso_report_qualquer_hora` | `accessReportAnyTime` | BooleanType | Acesso sem restrição de horário |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga DW |

- **Descartado da ODS:** `dt_extracao`, `dt_carga`, `reports`, `companies`, `groups`, `reportNames`
- **Contexto de uso:** Dimensão mais rica do modelo. Além de identificar o usuário, carrega todo o seu perfil de permissões. Permite análises de "quem pode fazer o quê" sem precisar cruzar com outras tabelas.

**Exemplos de insights:**
```sql
-- Usuários com permissão de download de .pbix (risco de exfiltração do modelo)
SELECT nm_usuario, nm_email, cd_perfil, nm_departamento
FROM dw_dim_user
WHERE fl_pode_baixar_pbix = true

-- Usuários com acesso expirando nos próximos 30 dias
SELECT nm_usuario, nm_email, dt_expiracao
FROM dw_dim_user
WHERE dt_expiracao BETWEEN CURRENT_DATE AND DATEADD(day, 30, CURRENT_DATE)
ORDER BY dt_expiracao

-- Distribuição de usuários por perfil
SELECT cd_perfil, COUNT(*) AS qtd_usuarios
FROM dw_dim_user
GROUP BY cd_perfil
ORDER BY qtd_usuarios DESC
```

---

### `dw_dim_group`

- **Fonte ODS:** `power_embedded_groups`
- **Tipo:** Dimensão
- **load_type:** `full` (overwrite)
- **Notebook:** `03_nb_dw_dim`

| Campo DW | Campo ODS | Tipo | Descrição |
|----------|-----------|------|-----------|
| `sk_group` | `id` | StringType | Surrogate key do grupo |
| `cd_organizacao` | `organizationId` | StringType | Código da organização |
| `nm_grupo` | `name` | StringType | Nome do grupo (usado como join key no bridge) |
| `ds_grupo` | `description` | StringType | Descrição |
| `fl_pode_editar_report` | `canEditReport` | BooleanType | Permissão de edição |
| `fl_pode_criar_report` | `canCreateReport` | BooleanType | Permissão de criação |
| `fl_pode_sobrescrever_report` | `canOverwriteReport` | BooleanType | Permissão de sobrescrita |
| `fl_pode_atualizar_dataset` | `canRefreshDataset` | BooleanType | Permissão de refresh |
| `fl_bypass_firewall` | `bypassFirewall` | BooleanType | Ignora restrições de firewall |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga DW |

- **Descartado da ODS:** `dt_extracao`, `dt_carga`, `reports`, `users`
- **Contexto de uso:** Grupos são a unidade de gestão de acesso RLS. Um usuário pertence a um ou mais grupos, e cada grupo tem roles RLS associadas em datasets. A análise de grupos revela como as políticas de segurança estão estruturadas.

**Exemplos de insights:**
```sql
-- Grupos com bypass de firewall ativo (verificar se é intencional)
SELECT nm_grupo, ds_grupo
FROM dw_dim_group
WHERE fl_bypass_firewall = true

-- Grupos sem descrição (dificulta auditoria de acesso)
SELECT nm_grupo, cd_organizacao
FROM dw_dim_group
WHERE ds_grupo IS NULL OR ds_grupo = ''
```

---

### `dw_dim_folder`

- **Fonte ODS:** `power_embedded_folders`
- **Tipo:** Dimensão
- **load_type:** `full` (overwrite)
- **Notebook:** `03_nb_dw_dim`

| Campo DW | Campo ODS | Tipo | Descrição |
|----------|-----------|------|-----------|
| `sk_folder` | `id` | StringType | Surrogate key da pasta |
| `cd_organizacao` | `organizationId` | StringType | Código da organização |
| `nm_pasta` | `name` | StringType | Nome da pasta |
| `fk_pasta_pai` | `parentFolderId` | StringType | FK para `dw_dim_folder.sk_folder` (hierarquia) |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga DW |

- **Contexto de uso:** Estrutura hierárquica para navegação e agrupamento de relatórios. Pastas de raiz têm `fk_pasta_pai = null`. Permite construir breadcrumb de localização dos relatórios no Power BI.

**Exemplos de insights:**
```sql
-- Pastas raiz (sem pai)
SELECT nm_pasta FROM dw_dim_folder WHERE fk_pasta_pai IS NULL

-- Quantos relatórios por pasta (join com dw_dim_report)
SELECT f.nm_pasta, COUNT(r.sk_report) AS qtd_relatorios
FROM dw_dim_folder f
LEFT JOIN dw_dim_report r ON r.fk_folder = f.sk_folder
GROUP BY f.nm_pasta
ORDER BY qtd_relatorios DESC
```

---

## Tabelas DW — Bridges

> Bridges resolvem relacionamentos N:N entre entidades. São fundamentais para responder "quem tem acesso a quê" e "qual segurança está aplicada a qual dado".

---

### `dw_bridge_permission`

- **Fonte ODS:** `power_embedded_permission_report`
- **Tipo:** Bridge (N:N entre relatório e usuário/grupo via RLS)
- **load_type:** `full` (overwrite)
- **Notebook:** `04_nb_dw_bridge_permission`
- **Depende de:** `dw_dim_dataset`, `dw_dim_report`, `dw_dim_user`, `dw_dim_group`, `dw_dim_folder`

| Campo | Origem | Tipo | Descrição |
|-------|--------|------|-----------|
| `cd_organizacao` | `organizationId` (ODS) | StringType | Código da organização |
| `cd_tipo_permissao` | `type` (ODS) | StringType | Tipo de permissão (ex: `GroupRlsPermission`) |
| `nm_email` | `userEmail` (ODS) | StringType | E-mail do usuário |
| `nm_report` | `reportName` (ODS) | StringType | Nome do relatório (join key) |
| `nm_workspace` | `workspaceName` (ODS) | StringType | Nome do workspace (join key junto com `nm_report`) |
| `nm_grupo_rls` | `rlsByGroup` limpo | StringType | Nome do grupo RLS sem prefixo "Group: " |
| `nm_role_rls` | `permissionDetail` limpo | StringType | Nome da role RLS sem prefixo "Role: " |
| `sk_user` | join com `dw_dim_user` por `nm_email` | StringType | Surrogate key do usuário |
| `sk_report` | join com `dw_dim_report` por `nm_report` + `nm_workspace` | StringType | Surrogate key do relatório |
| `sk_group` | join com `dw_dim_group` por `nm_grupo_rls` | StringType | Surrogate key do grupo (null se sem grupo RLS) |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga DW |

**Regras de negócio:**
- `rlsByGroup` contém prefixo `"Group: "` removido antes do join
- `permissionDetail` contém prefixo `"Role: "` removido; resultado vira `nm_role_rls`
- Joins são `left` — linhas sem match ficam com FK nula
- `sk_group` nulo é esperado para permissões sem grupo RLS associado

- **Contexto de uso:** Tabela central para análise de acesso. Responde diretamente "quais usuários têm acesso a quais relatórios, via qual grupo, com qual role RLS". É a ponte que conecta usuários a relatórios através da estrutura de grupos e roles.

**Exemplos de insights:**
```sql
-- Todos os relatórios que um usuário específico pode ver
SELECT r.nm_report, r.nm_workspace, p.nm_role_rls, p.nm_grupo_rls
FROM dw_bridge_permission p
JOIN dw_dim_user u ON p.sk_user = u.sk_user
JOIN dw_dim_report r ON p.sk_report = r.sk_report
WHERE u.nm_email = 'usuario@empresa.com'

-- Relatórios com maior quantidade de usuários com acesso
SELECT r.nm_report, r.nm_workspace, COUNT(DISTINCT p.sk_user) AS qtd_usuarios
FROM dw_bridge_permission p
JOIN dw_dim_report r ON p.sk_report = r.sk_report
GROUP BY r.nm_report, r.nm_workspace
ORDER BY qtd_usuarios DESC

-- Usuários com acesso a relatórios de múltiplos grupos RLS
-- (possível acesso mais amplo do que o esperado)
SELECT u.nm_usuario, u.nm_email, COUNT(DISTINCT p.nm_grupo_rls) AS qtd_grupos
FROM dw_bridge_permission p
JOIN dw_dim_user u ON p.sk_user = u.sk_user
GROUP BY u.nm_usuario, u.nm_email
HAVING COUNT(DISTINCT p.nm_grupo_rls) > 1
ORDER BY qtd_grupos DESC

-- Relatórios acessados por usuários que nunca fizeram login
-- (cross com dw_fact_identity_audit)
SELECT r.nm_report, u.nm_email
FROM dw_bridge_permission p
JOIN dw_dim_report r ON p.sk_report = r.sk_report
JOIN dw_dim_user u ON p.sk_user = u.sk_user
WHERE u.sk_user NOT IN (
    SELECT DISTINCT fk_user FROM dw_fact_identity_audit WHERE fl_status = true
)
```

---

### `dw_bridge_datasets_rls`

- **Fonte ODS:** `power_embedded_datasets_rls`
- **Tipo:** Bridge (N:N entre role RLS de dataset e usuários/grupos)
- **load_type:** `full` (overwrite)
- **Notebook:** `04_nb_dw_bridge_datasets_rls`
- **Depende de:** `dw_dim_dataset`, `dw_dim_user`

| Campo | Origem | Tipo | Descrição |
|-------|--------|------|-----------|
| `nk_role_rls` | `id` (ODS) | StringType | Natural key da role RLS |
| `nm_role_rls` | `name` (ODS) | StringType | Nome da role RLS |
| `sk_user` | explode de `users` array (ODS) | StringType | GUID do usuário = `sk_user` direto |
| `sk_group` | explode de `groups` array (ODS) | StringType | GUID do grupo = `sk_group` direto |
| `cd_tipo_membro` | calculado | StringType | `"User"` ou `"Group"` |
| `sk_dataset` | join com `dw_dim_dataset` por `nk_dataset_pbi` | StringType | Surrogate key do dataset |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga DW |

**Regras de negócio:**
- A ODS guarda `users` e `groups` como arrays JSON de GUIDs — o bridge explode cada array em linhas separadas
- GUIDs de usuários/grupos coincidem com `sk_user`/`sk_group` nas dims — join direto, sem lookup por nome
- `userEmails` descartado (redundante com `sk_user`)

- **Contexto de uso:** Enquanto `dw_bridge_permission` foca no acesso ao relatório, esta bridge foca na segurança em nível de dado — quais usuários/grupos têm qual role RLS em cada dataset. Essencial para auditar se a configuração de RLS no Power BI está correta e abrangente.

**Exemplos de insights:**
```sql
-- Datasets sem nenhuma role RLS configurada (todos veem tudo)
SELECT d.nm_dataset, d.cd_workspace
FROM dw_dim_dataset d
WHERE d.sk_dataset NOT IN (SELECT DISTINCT sk_dataset FROM dw_bridge_datasets_rls)
AND d.fl_requer_identidade_efetiva = false

-- Usuários com roles RLS em mais de 3 datasets diferentes (acesso amplo)
SELECT u.nm_usuario, u.nm_email, COUNT(DISTINCT b.sk_dataset) AS qtd_datasets
FROM dw_bridge_datasets_rls b
JOIN dw_dim_user u ON b.sk_user = u.sk_user
GROUP BY u.nm_usuario, u.nm_email
HAVING COUNT(DISTINCT b.sk_dataset) > 3

-- Distribuição de membros por tipo (usuário direto vs grupo)
SELECT nm_role_rls, cd_tipo_membro, COUNT(*) AS qtd_membros
FROM dw_bridge_datasets_rls
GROUP BY nm_role_rls, cd_tipo_membro
ORDER BY nm_role_rls
```

---

## Tabelas DW — Fatos

> Os fatos registram eventos que aconteceram no tempo. São as tabelas com maior volume e onde vivem os dados de comportamento e uso da plataforma.

---

### `dw_fact_report_audit`

- **Fonte ODS:** `power_embedded_report_audit`
- **Tipo:** Fato (eventos de acesso a relatórios)
- **load_type:** `full` (overwrite)
- **Notebook:** `05_nb_dw_fact_report_audit`
- **Depende de:** `dw_bridge_permission`

| Campo | Campo ODS | Tipo | Descrição |
|-------|-----------|------|-----------|
| `nk_evento` | `id` | StringType | Natural key do evento de auditoria |
| `dt_evento` | `createdAt` | TimestampType | Timestamp do evento |
| `cd_organizacao` | `organizationId` | StringType | Código da organização |
| `fk_user` | `userId` | StringType | FK para `dw_dim_user.sk_user` (join direto por GUID) |
| `fk_report` | `reportId` | StringType | FK para `dw_dim_report.sk_report` (join direto por GUID) |
| `cd_acao` | `action` | LongType | Código numérico da ação |
| `nm_acao` | `actionName` | StringType | Descrição da ação |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga DW |

**Regras de negócio:**
- `userEmail` e `reportName` descartados — disponíveis via join nas dimensões
- `fk_user` e `fk_report` são os GUIDs da API — coincidem diretamente com `sk_user` e `sk_report` nas dims
- Deduplicação por `nk_evento`

- **Contexto de uso:** Principal tabela de análise de uso e engajamento. Cada linha é uma interação de um usuário com um relatório. Responde perguntas como "quais relatórios são mais acessados?", "quais usuários são mais ativos?", "há usuários que nunca acessaram nenhum relatório?".

**Exemplos de insights:**
```sql
-- Top 10 relatórios mais acessados no último mês
SELECT r.nm_report, r.nm_workspace, COUNT(*) AS total_acessos
FROM dw_fact_report_audit f
JOIN dw_dim_report r ON f.fk_report = r.sk_report
WHERE f.dt_evento >= DATEADD(month, -1, CURRENT_DATE)
GROUP BY r.nm_report, r.nm_workspace
ORDER BY total_acessos DESC
LIMIT 10

-- Usuários cadastrados que nunca acessaram nenhum relatório (licença ociosa)
SELECT u.nm_usuario, u.nm_email, u.cd_perfil, u.nm_departamento
FROM dw_dim_user u
WHERE u.sk_user NOT IN (SELECT DISTINCT fk_user FROM dw_fact_report_audit)

-- Evolução semanal de acessos por relatório
SELECT
    DATE_TRUNC('week', dt_evento) AS semana,
    r.nm_report,
    COUNT(*) AS acessos,
    COUNT(DISTINCT fk_user) AS usuarios_unicos
FROM dw_fact_report_audit f
JOIN dw_dim_report r ON f.fk_report = r.sk_report
GROUP BY semana, r.nm_report
ORDER BY semana DESC, acessos DESC

-- Ações mais executadas (quais operações os usuários fazem)
SELECT nm_acao, COUNT(*) AS qtd
FROM dw_fact_report_audit
GROUP BY nm_acao
ORDER BY qtd DESC

-- Usuários com acesso concedido (bridge) mas sem nenhum acesso real (fato)
-- Identifica permissões concedidas desnecessariamente
SELECT u.nm_usuario, u.nm_email, r.nm_report
FROM dw_bridge_permission p
JOIN dw_dim_user u ON p.sk_user = u.sk_user
JOIN dw_dim_report r ON p.sk_report = r.sk_report
WHERE NOT EXISTS (
    SELECT 1 FROM dw_fact_report_audit f
    WHERE f.fk_user = u.sk_user AND f.fk_report = r.sk_report
)
```

---

### `dw_fact_email_audit`

- **Fonte ODS:** `power_embedded_email_audit`
- **Tipo:** Fato isolado (eventos de envio de e-mail)
- **load_type:** `full` (overwrite)
- **Notebook:** `05_nb_dw_fact_email_audit`
- **Depende de:** `dw_bridge_permission` (dependência de orquestração — sem FK real)

| Campo | Campo ODS | Tipo | Descrição |
|-------|-----------|------|-----------|
| `nk_email_audit` | `id` | StringType | Natural key do evento de e-mail |
| `cd_organizacao` | `organizationId` | StringType | Código da organização |
| `dt_envio` | `createdAt` | TimestampType | Timestamp do envio |
| `nm_template` | `templateName` | StringType | Template de e-mail utilizado |
| `ds_assunto` | `subject` | StringType | Assunto do e-mail |
| `nm_empresa` | `companyName` | StringType | Empresa destinatária |
| `nm_destino` | `destination` | StringType | Endereço de destino |
| `nm_smtp_host` | `smtpHost` | StringType | Servidor SMTP utilizado |
| `cd_status` | `status` | StringType/LongType | Código de status do envio |
| `ds_erro` | `error` | StringType | Mensagem de erro (null se sucesso) |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga DW |

**Regras de negócio:**
- Fato isolado — sem FKs para dimensões (os e-mails não referenciam usuários por ID)
- Deduplicação por `nk_email_audit`

- **Contexto de uso:** Rastreia a saúde da comunicação automatizada da plataforma. E-mails com falha de entrega (`ds_erro` preenchido) indicam problemas de configuração SMTP, endereços inválidos ou caixas cheias. Volume por empresa mostra o nível de atividade de notificações.

**Exemplos de insights:**
```sql
-- Taxa de falha de envio por servidor SMTP
SELECT
    nm_smtp_host,
    COUNT(*) AS total_envios,
    SUM(CASE WHEN ds_erro IS NOT NULL THEN 1 ELSE 0 END) AS total_falhas,
    ROUND(100.0 * SUM(CASE WHEN ds_erro IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_falha
FROM dw_fact_email_audit
GROUP BY nm_smtp_host
ORDER BY pct_falha DESC

-- Empresas com mais e-mails com erro (possível problema de domínio)
SELECT nm_empresa, COUNT(*) AS qtd_erros, ds_erro
FROM dw_fact_email_audit
WHERE ds_erro IS NOT NULL
GROUP BY nm_empresa, ds_erro
ORDER BY qtd_erros DESC

-- Volume de notificações por template ao longo do tempo
SELECT
    DATE_TRUNC('week', dt_envio) AS semana,
    nm_template,
    COUNT(*) AS qtd_envios
FROM dw_fact_email_audit
GROUP BY semana, nm_template
ORDER BY semana DESC
```

---

### `dw_fact_identity_audit`

- **Fonte ODS:** `power_embedded_identity_audit`
- **Tipo:** Fato (eventos de autenticação)
- **load_type:** `full` (overwrite na DW, fonte ODS é incremental)
- **Notebook:** `05_nb_dw_fact_identity_audit`
- **Depende de:** `dw_bridge_permission`

| Campo | Campo ODS | Tipo | Descrição |
|-------|-----------|------|-----------|
| `nk_identity_audit` | `id` | StringType | Natural key do evento de autenticação |
| `dt_evento` | `timeStamp` | TimestampType | Timestamp do evento |
| `cd_organizacao` | `organizationId` | StringType | Código da organização |
| `fk_user` | `userId` | StringType | FK para `dw_dim_user.sk_user` (join direto por GUID) |
| `cd_tipo_acao` | `actionType` | LongType | Código numérico do tipo de ação |
| `ds_user_agent` | `userAgent` | StringType | Browser/client utilizado |
| `ds_ip_address` | `ipAddress` | StringType | Endereço IP de origem |
| `fl_status` | `status` | BooleanType | `true` = sucesso, `false` = falha |
| `cd_modo_login` | `signInMode` | LongType | Código do modo de autenticação |
| `cd_tipo_erro` | `errorDescriptionType` | StringType/LongType | Código do tipo de erro (0 = sem erro) |
| `dt_carga` | — | TimestampType | Timestamp UTC da carga DW |

**Regras de negócio:**
- `userEmail` descartado — disponível via join em `dw_dim_user`
- `fk_user` coincide diretamente com `sk_user` na dim
- Deduplicação por `nk_identity_audit`
- `cd_tipo_erro` pode ter tipo inconsistente entre cargas — o schema alignment no ODS resolve antes de chegar aqui

- **Contexto de uso:** Histórico de autenticações da plataforma. Único endpoint incremental do projeto — acumula eventos ao longo do tempo. Fundamental para análises de segurança (tentativas de login falhadas, IPs suspeitos, usuários inativos) e padrões de uso (horários de pico, dispositivos mais usados).

**Exemplos de insights:**
```sql
-- Usuários com múltiplas falhas de login recentes (possível ataque ou conta com problema)
SELECT
    u.nm_usuario, u.nm_email,
    COUNT(*) AS qtd_falhas,
    MAX(f.dt_evento) AS ultima_falha
FROM dw_fact_identity_audit f
JOIN dw_dim_user u ON f.fk_user = u.sk_user
WHERE f.fl_status = false
  AND f.dt_evento >= DATEADD(day, -7, CURRENT_DATE)
GROUP BY u.nm_usuario, u.nm_email
HAVING COUNT(*) >= 5
ORDER BY qtd_falhas DESC

-- IPs com acesso de múltiplos usuários diferentes (possível IP compartilhado ou VPN)
SELECT ds_ip_address, COUNT(DISTINCT fk_user) AS qtd_usuarios
FROM dw_fact_identity_audit
WHERE fl_status = true
GROUP BY ds_ip_address
HAVING COUNT(DISTINCT fk_user) > 3
ORDER BY qtd_usuarios DESC

-- Usuários inativos (com acesso concedido mas sem login nos últimos 60 dias)
SELECT u.nm_usuario, u.nm_email, u.cd_perfil, MAX(f.dt_evento) AS ultimo_login
FROM dw_dim_user u
LEFT JOIN dw_fact_identity_audit f ON u.sk_user = f.fk_user AND f.fl_status = true
GROUP BY u.nm_usuario, u.nm_email, u.cd_perfil
HAVING MAX(f.dt_evento) < DATEADD(day, -60, CURRENT_DATE) OR MAX(f.dt_evento) IS NULL
ORDER BY ultimo_login ASC

-- Distribuição de logins por hora do dia (identificar horários de pico)
SELECT
    HOUR(dt_evento) AS hora,
    COUNT(*) AS qtd_logins,
    COUNT(DISTINCT fk_user) AS usuarios_unicos
FROM dw_fact_identity_audit
WHERE fl_status = true
GROUP BY HOUR(dt_evento)
ORDER BY hora

-- Dispositivos/browsers mais usados para acesso
SELECT
    ds_user_agent,
    COUNT(*) AS qtd_acessos,
    COUNT(DISTINCT fk_user) AS usuarios_unicos
FROM dw_fact_identity_audit
WHERE fl_status = true
GROUP BY ds_user_agent
ORDER BY qtd_acessos DESC
LIMIT 10
```

---

## Relacionamentos entre tabelas DW

```
dw_dim_folder ──────────────────────────────────────────────┐
                                                             ↓
dw_dim_dataset ←── fk_dataset ── dw_dim_report ←── fk_report ── dw_fact_report_audit
                                      ↑                              ↑
                                  sk_report                      fk_user
                                      │                              │
dw_dim_user ←── sk_user ─── dw_bridge_permission            dw_dim_user
     ↑                              │
  sk_user                       sk_group
     │                              │
dw_bridge_datasets_rls          dw_dim_group
     │
  sk_dataset
     │
dw_dim_dataset

dw_fact_identity_audit ──── fk_user ──→ dw_dim_user
dw_fact_email_audit ────── (sem FK — fato isolado)
```

**Análise cruzada mais poderosa — acesso concedido vs. acesso real vs. login:**
```sql
-- Para cada usuário: tem permissão? Fez login? Acessou relatórios?
SELECT
    u.nm_usuario,
    u.nm_email,
    u.cd_perfil,
    COUNT(DISTINCT p.sk_report)  AS relatorios_com_permissao,
    COUNT(DISTINCT fa.fk_report) AS relatorios_acessados,
    COUNT(DISTINCT ia.nk_identity_audit) AS total_logins,
    MAX(ia.dt_evento)            AS ultimo_login
FROM dw_dim_user u
LEFT JOIN dw_bridge_permission p       ON u.sk_user = p.sk_user
LEFT JOIN dw_fact_report_audit fa      ON u.sk_user = fa.fk_user
LEFT JOIN dw_fact_identity_audit ia    ON u.sk_user = ia.fk_user AND ia.fl_status = true
GROUP BY u.nm_usuario, u.nm_email, u.cd_perfil
ORDER BY relatorios_com_permissao DESC
```

---

**Projeto:** Enterprise / api-embedded
**Versão:** 1.1.0
**Atualizado em:** 2026-04-13

