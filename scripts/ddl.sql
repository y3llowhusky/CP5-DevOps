-- Execute no Azure SQL Database Argos (Query Editor ou sqlcmd). Idempotente.
IF OBJECT_ID(N'dbo.ZONAS_RISCO', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ZONAS_RISCO (
        Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ZONAS_RISCO PRIMARY KEY,
        Nome nvarchar(120) NOT NULL, Cidade nvarchar(120) NOT NULL,
        Estado nvarchar(2) NOT NULL, Latitude float NOT NULL, Longitude float NOT NULL,
        Regiao nvarchar(40) NULL, Descricao nvarchar(300) NULL,
        NivelRiscoAtual nvarchar(10) NOT NULL, Ativa bit NOT NULL,
        DataCriacao datetime2 NOT NULL, AtualizadoEm datetime2 NULL
    );
END;
IF OBJECT_ID(N'dbo.ALERTAS', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ALERTAS (
        Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ALERTAS PRIMARY KEY,
        ZonaRiscoId int NOT NULL, Titulo nvarchar(160) NOT NULL,
        Descricao nvarchar(2000) NOT NULL, NivelAlerta nvarchar(10) NOT NULL,
        Ativo bit NOT NULL, DataCriacao datetime2 NOT NULL,
        CONSTRAINT FK_ALERTAS_ZONAS_RISCO_ZonaRiscoId FOREIGN KEY (ZonaRiscoId)
            REFERENCES dbo.ZONAS_RISCO(Id) ON DELETE NO ACTION
    );
    CREATE INDEX IX_ALERTAS_ZonaRiscoId ON dbo.ALERTAS(ZonaRiscoId);
END;
