-- SQL Server Code Analysis Database Schema
-- Version: 1.0.0
-- Description: Creates tables and views for storing code analysis results with historical tracking
-- Usage: Execute against target database with appropriate permissions

SET NOCOUNT ON
PRINT 'Starting SQL Server Code Analysis Schema Creation...'

-- Create schema if not exists
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'CodeAnalysis')
BEGIN
    EXEC('CREATE SCHEMA CodeAnalysis')
    PRINT 'Created schema: CodeAnalysis'
END

-- =============================================
-- Table: CodeAnalysisRuns
-- Purpose: Metadata for each analysis execution
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'CodeAnalysisRuns' AND schema_id = SCHEMA_ID('CodeAnalysis'))
BEGIN
    CREATE TABLE CodeAnalysis.CodeAnalysisRuns (
        RunId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        StartTime DATETIME2(3) NOT NULL DEFAULT GETUTCDATE(),
        EndTime DATETIME2(3) NULL,
        SourceDirectory NVARCHAR(500) NOT NULL,
        ToolVersion NVARCHAR(50) NOT NULL,
        GitCommitHash NVARCHAR(100) NULL,
        BranchName NVARCHAR(255) NULL,
        GitAuthor NVARCHAR(255) NULL,
        ConfigurationUsed NVARCHAR(MAX) NULL, -- JSON configuration
        TotalFilesAnalyzed INT NOT NULL DEFAULT 0,
        TotalFilesChanged INT NOT NULL DEFAULT 0,
        TotalReferences INT NOT NULL DEFAULT 0,
        ProcessingTimeMs BIGINT NULL,
        Status NVARCHAR(20) NOT NULL DEFAULT 'Running', -- Running, Completed, Failed, Cancelled
        ErrorLog NVARCHAR(MAX) NULL,
        IsBaseline BIT NOT NULL DEFAULT 0,
        CreatedBy NVARCHAR(255) NOT NULL DEFAULT SYSTEM_USER,
        Notes NVARCHAR(1000) NULL,
        
        CONSTRAINT PK_CodeAnalysisRuns PRIMARY KEY (RunId),
        CONSTRAINT CK_CodeAnalysisRuns_Status CHECK (Status IN ('Running', 'Completed', 'Failed', 'Cancelled'))
    )
    
    -- Indexes for performance
    CREATE NONCLUSTERED INDEX IX_CodeAnalysisRuns_StartTime ON CodeAnalysis.CodeAnalysisRuns (StartTime DESC)
    CREATE NONCLUSTERED INDEX IX_CodeAnalysisRuns_SourceDirectory ON CodeAnalysis.CodeAnalysisRuns (SourceDirectory)
    CREATE NONCLUSTERED INDEX IX_CodeAnalysisRuns_Status ON CodeAnalysis.CodeAnalysisRuns (Status)
    CREATE NONCLUSTERED INDEX IX_CodeAnalysisRuns_GitCommit ON CodeAnalysis.CodeAnalysisRuns (GitCommitHash) WHERE GitCommitHash IS NOT NULL
    
    PRINT 'Created table: CodeAnalysis.CodeAnalysisRuns'
END

-- =============================================
-- Table: SqlObjectCatalog
-- Purpose: Master catalog of discovered SQL objects
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SqlObjectCatalog' AND schema_id = SCHEMA_ID('CodeAnalysis'))
BEGIN
    CREATE TABLE CodeAnalysis.SqlObjectCatalog (
        ObjectId BIGINT IDENTITY(1,1) NOT NULL,
        SchemaName NVARCHAR(128) NOT NULL DEFAULT 'dbo',
        ObjectName NVARCHAR(128) NOT NULL,
        ObjectType NVARCHAR(50) NOT NULL, -- Table, View, StoredProcedure, Function, Synonym, etc.
        FirstDiscoveredRunId UNIQUEIDENTIFIER NOT NULL,
        FirstDiscoveredDate DATETIME2(3) NOT NULL DEFAULT GETUTCDATE(),
        LastSeenRunId UNIQUEIDENTIFIER NOT NULL,
        LastSeenDate DATETIME2(3) NOT NULL DEFAULT GETUTCDATE(),
        CurrentStatus NVARCHAR(20) NOT NULL DEFAULT 'Active', -- Active, Deprecated, Removed
        ValidationStatus NVARCHAR(20) NULL, -- Exists, NotFound, NoPermission, NotValidated
        ValidationDate DATETIME2(3) NULL,
        DependencyCount INT NOT NULL DEFAULT 0,
        RiskLevel NVARCHAR(10) NOT NULL DEFAULT 'Unknown', -- Low, Medium, High, Critical, Unknown
        Notes NVARCHAR(1000) NULL,
        
        CONSTRAINT PK_SqlObjectCatalog PRIMARY KEY (ObjectId),
        CONSTRAINT FK_SqlObjectCatalog_FirstDiscovered FOREIGN KEY (FirstDiscoveredRunId) REFERENCES CodeAnalysis.CodeAnalysisRuns(RunId),
        CONSTRAINT FK_SqlObjectCatalog_LastSeen FOREIGN KEY (LastSeenRunId) REFERENCES CodeAnalysis.CodeAnalysisRuns(RunId),
        CONSTRAINT CK_SqlObjectCatalog_ObjectType CHECK (ObjectType IN ('Table', 'View', 'StoredProcedure', 'Function', 'Synonym', 'Trigger', 'UserDefinedType', 'Other')),
        CONSTRAINT CK_SqlObjectCatalog_Status CHECK (CurrentStatus IN ('Active', 'Deprecated', 'Removed')),
        CONSTRAINT CK_SqlObjectCatalog_ValidationStatus CHECK (ValidationStatus IN ('Exists', 'NotFound', 'NoPermission', 'NotValidated')),
        CONSTRAINT CK_SqlObjectCatalog_RiskLevel CHECK (RiskLevel IN ('Low', 'Medium', 'High', 'Critical', 'Unknown'))
    )
    
    -- Unique constraint on schema + object name
    CREATE UNIQUE NONCLUSTERED INDEX UX_SqlObjectCatalog_Object ON CodeAnalysis.SqlObjectCatalog (SchemaName, ObjectName)
    CREATE NONCLUSTERED INDEX IX_SqlObjectCatalog_ObjectType ON CodeAnalysis.SqlObjectCatalog (ObjectType)
    CREATE NONCLUSTERED INDEX IX_SqlObjectCatalog_Status ON CodeAnalysis.SqlObjectCatalog (CurrentStatus)
    CREATE NONCLUSTERED INDEX IX_SqlObjectCatalog_LastSeen ON CodeAnalysis.SqlObjectCatalog (LastSeenDate DESC)
    
    PRINT 'Created table: CodeAnalysis.SqlObjectCatalog'
END

-- =============================================
-- Table: FileAnalysisHistory
-- Purpose: File-level analysis metadata and change tracking
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'FileAnalysisHistory' AND schema_id = SCHEMA_ID('CodeAnalysis'))
BEGIN
    CREATE TABLE CodeAnalysis.FileAnalysisHistory (
        FileHistoryId BIGINT IDENTITY(1,1) NOT NULL,
        RunId UNIQUEIDENTIFIER NOT NULL,
        FilePath NVARCHAR(500) NOT NULL,
        RelativePath NVARCHAR(500) NOT NULL, -- Path relative to source directory
        FileName NVARCHAR(255) NOT NULL,
        FileExtension NVARCHAR(10) NOT NULL,
        FileSize BIGINT NOT NULL,
        FileHash NVARCHAR(64) NOT NULL, -- SHA-256 hash
        LastModified DATETIME2(3) NOT NULL,
        LineCount INT NOT NULL DEFAULT 0,
        AnalysisStatus NVARCHAR(20) NOT NULL DEFAULT 'Pending', -- Pending, Completed, Failed, Skipped
        ErrorDetails NVARCHAR(MAX) NULL,
        ProcessingTimeMs INT NULL,
        ReferenceCount INT NOT NULL DEFAULT 0,
        HasChanges BIT NOT NULL DEFAULT 0, -- Indicates if file changed since last run
        ChangeType NVARCHAR(20) NULL, -- Added, Modified, Deleted, Renamed
        PreviousFilePath NVARCHAR(500) NULL, -- For renamed files
        
        CONSTRAINT PK_FileAnalysisHistory PRIMARY KEY (FileHistoryId),
        CONSTRAINT FK_FileAnalysisHistory_RunId FOREIGN KEY (RunId) REFERENCES CodeAnalysis.CodeAnalysisRuns(RunId),
        CONSTRAINT CK_FileAnalysisHistory_Status CHECK (AnalysisStatus IN ('Pending', 'Completed', 'Failed', 'Skipped')),
        CONSTRAINT CK_FileAnalysisHistory_ChangeType CHECK (ChangeType IN ('Added', 'Modified', 'Deleted', 'Renamed'))
    )
    
    -- Indexes for performance
    CREATE NONCLUSTERED INDEX IX_FileAnalysisHistory_RunId ON CodeAnalysis.FileAnalysisHistory (RunId)
    CREATE NONCLUSTERED INDEX IX_FileAnalysisHistory_FilePath ON CodeAnalysis.FileAnalysisHistory (FilePath)
    CREATE NONCLUSTERED INDEX IX_FileAnalysisHistory_FileHash ON CodeAnalysis.FileAnalysisHistory (FileHash)
    CREATE NONCLUSTERED INDEX IX_FileAnalysisHistory_Extension ON CodeAnalysis.FileAnalysisHistory (FileExtension)
    CREATE NONCLUSTERED INDEX IX_FileAnalysisHistory_HasChanges ON CodeAnalysis.FileAnalysisHistory (HasChanges) WHERE HasChanges = 1
    
    PRINT 'Created table: CodeAnalysis.FileAnalysisHistory'
END
-- =============================================
-- Table: CodeAnalysisHistory
-- Purpose: Detailed findings for each analysis run
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'CodeAnalysisHistory' AND schema_id = SCHEMA_ID('CodeAnalysis'))
BEGIN
    CREATE TABLE CodeAnalysis.CodeAnalysisHistory (
        HistoryId BIGINT IDENTITY(1,1) NOT NULL,
        RunId UNIQUEIDENTIFIER NOT NULL,
        FileHistoryId BIGINT NOT NULL,
        ObjectId BIGINT NULL, -- Links to SqlObjectCatalog
        LineNumber INT NOT NULL,
        CodeBlockType NVARCHAR(50) NOT NULL, -- Class, Method, Property, Function, Constructor, etc.
        CodeBlockName NVARCHAR(255) NOT NULL,
        NamespaceName NVARCHAR(255) NULL,
        ClassName NVARCHAR(255) NULL,
        MethodName NVARCHAR(255) NULL,
        SqlObjectType NVARCHAR(50) NOT NULL, -- Table, View, StoredProcedure, Function, Parameter, Column
        SchemaName NVARCHAR(128) NULL,
        ObjectName NVARCHAR(128) NOT NULL,
        ColumnName NVARCHAR(128) NULL,
        ParameterName NVARCHAR(128) NULL,
        ParameterType NVARCHAR(50) NULL,
        ParameterDirection NVARCHAR(20) NULL, -- Input, Output, InputOutput, ReturnValue
        SqlStatement NVARCHAR(MAX) NULL, -- Full or partial SQL statement
        AdoNetObjectType NVARCHAR(50) NULL, -- SqlCommand, SqlDataAdapter, SqlConnection, etc.
        AdoNetProperty NVARCHAR(100) NULL, -- CommandText, SelectCommand, ConnectionString, etc.
        ConnectionStringName NVARCHAR(128) NULL,
        DatabaseName NVARCHAR(128) NULL,
        CommandType NVARCHAR(20) NULL, -- Text, StoredProcedure, TableDirect
        SourceCodeSnippet NVARCHAR(1000) NULL, -- Context around the reference
        Confidence TINYINT NOT NULL DEFAULT 50, -- 1-100 confidence level
        DetectionMethod NVARCHAR(100) NOT NULL, -- RegexPattern, AstAnalysis, StringLiteral, etc.
        IsDeprecated BIT NOT NULL DEFAULT 0,
        RiskFlags NVARCHAR(500) NULL, -- Comma-separated risk indicators
        Notes NVARCHAR(500) NULL,
        
        CONSTRAINT PK_CodeAnalysisHistory PRIMARY KEY (HistoryId),
        CONSTRAINT FK_CodeAnalysisHistory_RunId FOREIGN KEY (RunId) REFERENCES CodeAnalysis.CodeAnalysisRuns(RunId),
        CONSTRAINT FK_CodeAnalysisHistory_FileHistoryId FOREIGN KEY (FileHistoryId) REFERENCES CodeAnalysis.FileAnalysisHistory(FileHistoryId),
        CONSTRAINT FK_CodeAnalysisHistory_ObjectId FOREIGN KEY (ObjectId) REFERENCES CodeAnalysis.SqlObjectCatalog(ObjectId),
        CONSTRAINT CK_CodeAnalysisHistory_Confidence CHECK (Confidence BETWEEN 1 AND 100),
        CONSTRAINT CK_CodeAnalysisHistory_SqlObjectType CHECK (SqlObjectType IN ('Table', 'View', 'StoredProcedure', 'Function', 'Parameter', 'Column', 'Synonym', 'Trigger', 'Other')),
        CONSTRAINT CK_CodeAnalysisHistory_ParameterDirection CHECK (ParameterDirection IN ('Input', 'Output', 'InputOutput', 'ReturnValue')),
        CONSTRAINT CK_CodeAnalysisHistory_CommandType CHECK (CommandType IN ('Text', 'StoredProcedure', 'TableDirect'))
    )
    
    -- Indexes for performance
    CREATE NONCLUSTERED INDEX IX_CodeAnalysisHistory_RunId ON CodeAnalysis.CodeAnalysisHistory (RunId)
    CREATE NONCLUSTERED INDEX IX_CodeAnalysisHistory_FileHistoryId ON CodeAnalysis.CodeAnalysisHistory (FileHistoryId)
    CREATE NONCLUSTERED INDEX IX_CodeAnalysisHistory_ObjectId ON CodeAnalysis.CodeAnalysisHistory (ObjectId) WHERE ObjectId IS NOT NULL
    CREATE NONCLUSTERED INDEX IX_CodeAnalysisHistory_ObjectName ON CodeAnalysis.CodeAnalysisHistory (SchemaName, ObjectName)
    CREATE NONCLUSTERED INDEX IX_CodeAnalysisHistory_SqlObjectType ON CodeAnalysis.CodeAnalysisHistory (SqlObjectType)
    CREATE NONCLUSTERED INDEX IX_CodeAnalysisHistory_CodeBlock ON CodeAnalysis.CodeAnalysisHistory (CodeBlockType, CodeBlockName)
    CREATE NONCLUSTERED INDEX IX_CodeAnalysisHistory_AdoNetType ON CodeAnalysis.CodeAnalysisHistory (AdoNetObjectType) WHERE AdoNetObjectType IS NOT NULL
    
    PRINT 'Created table: CodeAnalysis.CodeAnalysisHistory'
END

-- =============================================
-- Table: AnalysisConfiguration
-- Purpose: Store configuration templates and settings
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AnalysisConfiguration' AND schema_id = SCHEMA_ID('CodeAnalysis'))
BEGIN
    CREATE TABLE CodeAnalysis.AnalysisConfiguration (
        ConfigId INT IDENTITY(1,1) NOT NULL,
        ConfigName NVARCHAR(100) NOT NULL,
        ConfigDescription NVARCHAR(500) NULL,
        ConfigJson NVARCHAR(MAX) NOT NULL, -- JSON configuration
        IsDefault BIT NOT NULL DEFAULT 0,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedDate DATETIME2(3) NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy NVARCHAR(255) NOT NULL DEFAULT SYSTEM_USER,
        ModifiedDate DATETIME2(3) NOT NULL DEFAULT GETUTCDATE(),
        ModifiedBy NVARCHAR(255) NOT NULL DEFAULT SYSTEM_USER,
        
        CONSTRAINT PK_AnalysisConfiguration PRIMARY KEY (ConfigId),
        CONSTRAINT UX_AnalysisConfiguration_Name UNIQUE (ConfigName)
    )
    
    CREATE NONCLUSTERED INDEX IX_AnalysisConfiguration_IsDefault ON CodeAnalysis.AnalysisConfiguration (IsDefault) WHERE IsDefault = 1
    
    PRINT 'Created table: CodeAnalysis.AnalysisConfiguration'
END

PRINT 'Database schema creation completed successfully!'
PRINT 'Total tables created: 5'
PRINT 'Next step: Execute views_creation.sql to create analysis views'
