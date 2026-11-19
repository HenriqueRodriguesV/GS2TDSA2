/* =============================================================================
   Refugio 360 - DDL do banco de dados (Azure SQL Database / SQL Server)
   Global Solution 2026/2 - DevOps Tools & Cloud Computing - GS The Last Dance
   =============================================================================
   Executado automaticamente pela pipeline de Release (tarefa "Azure SQL
   Database deployment") antes do deploy da API. O script e idempotente: cada
   objeto so e criado se ainda nao existir, entao pode rodar a cada release.

   Tabelas (geradas a partir das entidades JPA da API):
     tb_usuario           cidadaos e gestores (login local ou Firebase)
     tb_local_seguro      abrigos, UBS e pontos de agua            -> CRUD
     tb_ponto_risco       areas de risco mapeadas pelo gestor      -> CRUD
     tb_ocorrencia        relatos dos cidadaos (FK tb_usuario)     -> CRUD
     tb_orientacao        orientacoes geradas para uma ocorrencia (FK tb_ocorrencia)
     tb_orientacao_local  N:N entre orientacao e locais seguros considerados
   ============================================================================= */

-- Opcoes exigidas pelo indice unico filtrado (firebase_uid) e recomendadas
-- para Azure SQL; o sqlcmd usado na Release desliga QUOTED_IDENTIFIER por padrao.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---------------------------------------------------------------------------
   tb_usuario: perfil local de cada pessoa. papel = CIDADAO | GESTOR.
   O e-mail e unico; o firebase_uid e unico quando preenchido.
   --------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.tb_usuario', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.tb_usuario (
        id            BIGINT IDENTITY(1,1) NOT NULL,
        email         VARCHAR(255)         NOT NULL,
        senha         VARCHAR(255)         NOT NULL,  -- hash BCrypt, nunca texto puro
        papel         VARCHAR(255)         NOT NULL,  -- CIDADAO | GESTOR
        firebase_uid  VARCHAR(255)         NULL,
        CONSTRAINT pk_usuario PRIMARY KEY (id),
        CONSTRAINT uk_usuario_email UNIQUE (email)
    );
END;
GO

SET QUOTED_IDENTIFIER ON;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'uk_usuario_firebase_uid')
    CREATE UNIQUE NONCLUSTERED INDEX uk_usuario_firebase_uid
        ON dbo.tb_usuario (firebase_uid) WHERE firebase_uid IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   tb_local_seguro: locais de apoio durante ondas de calor, enchentes e falta
   de energia. tipo = ABRIGO | UBS | PONTO_AGUA ...
   --------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.tb_local_seguro', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.tb_local_seguro (
        id         BIGINT IDENTITY(1,1) NOT NULL,
        nome       VARCHAR(255)         NOT NULL,
        tipo       VARCHAR(255)         NOT NULL,
        endereco   VARCHAR(255)         NOT NULL,
        latitude   FLOAT(53)            NOT NULL,
        longitude  FLOAT(53)            NOT NULL,
        descricao  VARCHAR(255)         NULL,
        CONSTRAINT pk_local_seguro PRIMARY KEY (id)
    );
END;
GO

/* ---------------------------------------------------------------------------
   tb_ponto_risco: areas de risco. nivel_perigo = BAIXO | MODERADO | ALTO | CRITICO
   --------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.tb_ponto_risco', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.tb_ponto_risco (
        id            BIGINT IDENTITY(1,1) NOT NULL,
        titulo        VARCHAR(255)         NOT NULL,
        nivel_perigo  VARCHAR(255)         NOT NULL,
        latitude      FLOAT(53)            NOT NULL,
        longitude     FLOAT(53)            NOT NULL,
        CONSTRAINT pk_ponto_risco PRIMARY KEY (id)
    );
END;
GO

/* ---------------------------------------------------------------------------
   tb_ocorrencia: relato do cidadao. urgencia = BAIXA | MEDIA | ALTA | CRITICA;
   status = PENDENTE -> EM_ANALISE -> RESOLVIDA; perfil = GERAL | IDOSO | PCD | FAMILIA
   --------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.tb_ocorrencia', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.tb_ocorrencia (
        id         BIGINT IDENTITY(1,1) NOT NULL,
        descricao  VARCHAR(255)         NOT NULL,
        urgencia   VARCHAR(255)         NOT NULL,
        status     VARCHAR(255)         NULL,
        perfil     VARCHAR(255)         NULL,
        latitude   FLOAT(53)            NULL,
        longitude  FLOAT(53)            NULL,
        autor_id   BIGINT               NULL,
        CONSTRAINT pk_ocorrencia PRIMARY KEY (id),
        CONSTRAINT fk_ocorrencia_usuario FOREIGN KEY (autor_id) REFERENCES dbo.tb_usuario (id)
    );
END;
GO

/* ---------------------------------------------------------------------------
   tb_orientacao: orientacao (IA ou alternativa local) para uma ocorrencia.
   Removida junto com a ocorrencia (cascata feita pela API).
   --------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.tb_orientacao', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.tb_orientacao (
        id             BIGINT IDENTITY(1,1) NOT NULL,
        ocorrencia_id  BIGINT               NOT NULL,
        mensagem       VARCHAR(2000)        NOT NULL,
        perfil         VARCHAR(255)         NULL,
        gerado_poria   BIT                  NOT NULL,  -- 1 = gerada pela IA (Gemini)
        criada_em      DATETIMEOFFSET(6)    NOT NULL,
        CONSTRAINT pk_orientacao PRIMARY KEY (id),
        CONSTRAINT fk_orientacao_ocorrencia FOREIGN KEY (ocorrencia_id) REFERENCES dbo.tb_ocorrencia (id)
    );
END;
GO

/* ---------------------------------------------------------------------------
   tb_orientacao_local: locais seguros considerados em cada orientacao (N:N).
   --------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.tb_orientacao_local', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.tb_orientacao_local (
        orientacao_id  BIGINT NOT NULL,
        local_id       BIGINT NOT NULL,
        CONSTRAINT fk_orientacao_local_orientacao FOREIGN KEY (orientacao_id) REFERENCES dbo.tb_orientacao (id),
        CONSTRAINT fk_orientacao_local_local FOREIGN KEY (local_id) REFERENCES dbo.tb_local_seguro (id)
    );
END;
GO

/* =============================================================================
   Consultas de conferencia (usadas no video para comprovar cada operacao do CRUD)
   =============================================================================
   SELECT id, nome, tipo, endereco, latitude, longitude, descricao FROM dbo.tb_local_seguro ORDER BY id DESC;
   SELECT id, titulo, nivel_perigo, latitude, longitude FROM dbo.tb_ponto_risco ORDER BY id DESC;
   SELECT id, descricao, urgencia, status, perfil, autor_id FROM dbo.tb_ocorrencia ORDER BY id DESC;
   ============================================================================= */
