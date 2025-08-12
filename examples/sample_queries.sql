-- Example SQL queries for analyzing code analysis results
-- Run these queries after performing code analysis to get insights

-- =============================================
-- Query 1: Get overview of latest analysis
-- =============================================
SELECT 
    car.RunId,
    car.StartTime,
    car.SourceDirectory,
    car.TotalFilesAnalyzed,
    car.TotalReferences,
    car.ProcessingTimeMs / 1000.0 AS ProcessingTimeSeconds,
    car.Status
FROM CodeAnalysis.CodeAnalysisRuns car
WHERE car.Status = 'Completed'
ORDER BY car.StartTime DESC

-- =============================================
-- Query 2: Top SQL objects by usage
-- =============================================
SELECT TOP 20
    SchemaName,
    ObjectName,
    SqlObjectType,
    TotalReferences,
    FilesReferencing,
    ClassesReferencing,
    UsagePattern,
    UsageRiskLevel
FROM CodeAnalysis.vw_SqlObjectUsage
ORDER BY TotalReferences DESC

-- =============================================
-- Query 3: Files with most SQL references
-- =============================================
SELECT TOP 20
    RelativePath,
    FileName,
    FileExtension,
    ReferenceCount,
    UniqueSqlObjects,
    UsageClassification,
    ReferenceDensity
FROM CodeAnalysis.vw_FileAnalysisSummary
ORDER BY ReferenceCount DESC

-- =============================================
-- Query 4: ADO.NET usage patterns
-- =============================================
SELECT 
    PatternType,
    COUNT(*) AS UsageCount,
    COUNT(DISTINCT RelativePath) AS FilesUsing,
    AVG(AverageConfidence) AS AvgConfidence,
    SUM(CASE WHEN RiskAssessment = 'High Risk' THEN 1 ELSE 0 END) AS HighRiskCount
FROM CodeAnalysis.vw_AdoNetPatterns
GROUP BY PatternType
ORDER BY UsageCount DESC

-- =============================================
-- Query 5: Recent changes between analysis runs
-- =============================================
SELECT 
    ChangeType,
    COUNT(*) AS ChangeCount,
    STRING_AGG(DISTINCT SqlObjectType, ', ') AS ObjectTypes,
    STRING_AGG(DISTINCT CONCAT(SchemaName, '.', ObjectName), ', ') AS Objects
FROM CodeAnalysis.vw_CodeAnalysisChanges
GROUP BY ChangeType
ORDER BY ChangeCount DESC

-- =============================================
-- Query 6: Risk assessment summary
-- =============================================
SELECT 
    'High Risk References' AS Metric,
    COUNT(*) AS Count
FROM CodeAnalysis.vw_LatestCodeAnalysis
WHERE RiskFlags IS NOT NULL

UNION ALL

SELECT 
    'Deprecated References' AS Metric,
    COUNT(*) AS Count
FROM CodeAnalysis.vw_LatestCodeAnalysis
WHERE IsDeprecated = 1

UNION ALL

SELECT 
    'Low Confidence References' AS Metric,
    COUNT(*) AS Count
FROM CodeAnalysis.vw_LatestCodeAnalysis
WHERE Confidence < 50

-- =============================================
-- Query 7: SQL object types distribution
-- =============================================
SELECT 
    SqlObjectType,
    COUNT(*) AS ReferenceCount,
    COUNT(DISTINCT CONCAT(SchemaName, '.', ObjectName)) AS UniqueObjects,
    AVG(CAST(Confidence AS FLOAT)) AS AvgConfidence
FROM CodeAnalysis.vw_LatestCodeAnalysis
GROUP BY SqlObjectType
ORDER BY ReferenceCount DESC

-- =============================================
-- Query 8: Code organization analysis
-- =============================================
SELECT 
    CASE 
        WHEN NamespaceName IS NOT NULL THEN NamespaceName
        ELSE 'No Namespace'
    END AS Namespace,
    COUNT(*) AS SqlReferences,
    COUNT(DISTINCT ObjectName) AS UniqueObjects,
    COUNT(DISTINCT ClassName) AS Classes,
    COUNT(DISTINCT CONCAT(ClassName, '.', MethodName)) AS Methods
FROM CodeAnalysis.vw_LatestCodeAnalysis
GROUP BY CASE WHEN NamespaceName IS NOT NULL THEN NamespaceName ELSE 'No Namespace' END
ORDER BY SqlReferences DESC

-- =============================================
-- Query 9: Find potential SQL injection risks
-- =============================================
SELECT 
    RelativePath,
    ClassName,
    MethodName,
    LineNumber,
    SqlStatement,
    RiskFlags,
    SourceCodeSnippet
FROM CodeAnalysis.vw_LatestCodeAnalysis
WHERE RiskFlags LIKE '%SQL Injection%' 
   OR (CommandType = 'Text' AND SqlStatement LIKE '%+%')
   OR SourceCodeSnippet LIKE '%String.Format%'
ORDER BY RelativePath, LineNumber

-- =============================================
-- Query 10: Database connection analysis
-- =============================================
SELECT 
    ConnectionStringName,
    DatabaseName,
    COUNT(*) AS UsageCount,
    COUNT(DISTINCT RelativePath) AS FilesUsing,
    STRING_AGG(DISTINCT AdoNetObjectType, ', ') AS AdoNetTypes
FROM CodeAnalysis.vw_LatestCodeAnalysis
WHERE ConnectionStringName IS NOT NULL OR DatabaseName IS NOT NULL
GROUP BY ConnectionStringName, DatabaseName
ORDER BY UsageCount DESC
