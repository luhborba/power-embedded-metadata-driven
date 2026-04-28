-- =============================================================================
-- Power Embedded — SQL Database de Controle
-- Artefato: sqldb_powerembedded_controle
-- Script: Criação + população da tabela powerembedded_control
-- Executar no novo ambiente antes da primeira execução do pipeline
-- =============================================================================


-- -----------------------------------------------------------------------------
-- DROP (opcional) — descomente só se quiser recriar do zero
-- -----------------------------------------------------------------------------
-- DROP TABLE IF EXISTS powerembedded_control;


-- -----------------------------------------------------------------------------
-- CREATE TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE powerembedded_control (
    id                  INT IDENTITY(1,1) PRIMARY KEY,
    endpoint            VARCHAR(100) NOT NULL,
    endpoint_alias      VARCHAR(100) NOT NULL,
    is_paginated        BIT          NOT NULL DEFAULT 1,
    load_type           VARCHAR(30)  NOT NULL,       -- full | incremental_datetime
    delta_param_start   VARCHAR(50)  NULL,           -- ex: startDateTime
    delta_param_end     VARCHAR(50)  NULL,           -- ex: endDateTime
    last_delta_value    VARCHAR(50)  NULL,           -- último endDateTime executado (atualizado pelo nb_landing)
    run_landing         BIT          NOT NULL DEFAULT 1,
    run_ods             BIT          NOT NULL DEFAULT 1,
    run_dw              BIT          NOT NULL DEFAULT 1,
    is_active           BIT          NOT NULL DEFAULT 1,
    concurrency_group   VARCHAR(20)  NOT NULL DEFAULT 'normal'  -- normal | heavy
);


-- -----------------------------------------------------------------------------
-- INSERT — todos os endpoints
-- Colunas delta_param_* e last_delta_value só são preenchidas para
-- endpoints com load_type = 'incremental_datetime' (capacity_audit, identity_audit).
-- last_delta_value começa NULL — nb_landing usará '2024-01-01T00:00:00' como
-- start na primeira execução conforme lógica do notebook.
-- -----------------------------------------------------------------------------
INSERT INTO powerembedded_control
    (endpoint, endpoint_alias, is_paginated, load_type, delta_param_start, delta_param_end, last_delta_value, run_landing, run_ods, run_dw, is_active, concurrency_group)
VALUES
    -- Endpoints full / normal
    ('/api/datasets',                'datasets',                  1, 'full',                   NULL,            NULL,          NULL, 1, 1, 1, 1, 'normal'),
    ('/api/datasets/rls',            'datasets_rls',              1, 'full',                   NULL,            NULL,          NULL, 1, 1, 1, 1, 'normal'),
    ('/api/datasets/refresh-history','datasets_refresh_history',  1, 'full',                   NULL,            NULL,          NULL, 1, 1, 1, 1, 'normal'),
    ('/api/email-audit',             'email_audit',               1, 'full',                   NULL,            NULL,          NULL, 1, 1, 1, 1, 'normal'),
    ('/api/folders',                 'folders',                   0, 'full',                   NULL,            NULL,          NULL, 1, 1, 1, 1, 'normal'),
    ('/api/groups',                  'groups',                    1, 'full',                   NULL,            NULL,          NULL, 1, 1, 1, 1, 'normal'),
    ('/api/permission-report',       'permission_report',         1, 'full',                   NULL,            NULL,          NULL, 1, 1, 1, 1, 'normal'),
    ('/api/report-access-requests',  'report_access_requests',    1, 'full',                   NULL,            NULL,          NULL, 1, 1, 1, 1, 'normal'),
    ('/api/report-audit',            'report_audit',              1, 'incremental_datetime',   'startDateTime', 'endDateTime', NULL, 1, 1, 1, 1, 'normal'),
    ('/api/report',                  'report',                    1, 'full',                   NULL,            NULL,          NULL, 1, 1, 1, 1, 'normal'),
    ('/api/user',                    'user',                      1, 'full',                   NULL,            NULL,          NULL, 1, 1, 1, 1, 'normal'),

    -- Endpoints incrementais / heavy
    ('/api/capacity-audit',          'capacity_audit',            1, 'incremental_datetime',   'startDateTime', 'endDateTime', NULL, 1, 1, 1, 1, 'heavy'),
    ('/api/identity-audit',          'identity_audit',            1, 'incremental_datetime',   'startDateTime', 'endDateTime', NULL, 1, 1, 1, 1, 'heavy');


-- -----------------------------------------------------------------------------
-- Verificação
-- -----------------------------------------------------------------------------
SELECT
    id,
    endpoint_alias,
    load_type,
    is_paginated,
    concurrency_group,
    is_active,
    run_landing,
    run_ods,
    run_dw,
    last_delta_value
FROM powerembedded_control
ORDER BY id;

