# SQL Server Code Analysis Tool - Requirements

## Primary Objective
Create a comprehensive database-backed tool that analyzes source code files to identify SQL Server database object references, ADO.NET usage patterns, and Entity Framework mappings. Store historical analysis data in SQL Server tables with timestamps for trend analysis and change detection over time.

## Core Architecture

### Database-First Approach
- **Persistent Storage**: All analysis results stored in SQL Server tables
- **Historical Tracking**: Maintain complete history of all analysis runs with timestamps
- **Change Detection**: Identify additions, modifications, and deletions between analysis runs
- **Incremental Processing**: Support for processing only changed files
- **Data Retention**: Configurable retention policies for historical data management

### Time-Series Analysis
- **Baseline Establishment**: Mark specific runs as baselines for comparison
- **Trend Analysis**: Track SQL object usage patterns over time
- **Impact Assessment**: Measure effects of code changes on database dependencies
- **Regression Detection**: Identify when deprecated objects reappear in code

## Database Deployment Requirements

### Live Database Integration
- **Connection Parameters**: Accept server, database, username, password via command line or config
- **Auto-Schema Creation**: CREATE IF NOT EXISTS logic for all tables and indexes
- **View Management**: CREATE OR ALTER for all analysis views
- **Transaction Safety**: All schema changes wrapped in transactions with rollback capability
- **Permission Validation**: Verify required database permissions before execution
- **Connection Security**: Support Windows Authentication, SQL Authentication, Azure AD
- **Connection String Management**: Support Azure Key Vault and encrypted connection strings

### Deployment Modes
- **Live Mode**: Direct execution against target SQL Server instance
- **Script Mode**: Generate T-SQL scripts for manual deployment
- **Hybrid Mode**: Execute live and optionally save scripts for audit trail
- **Dry Run Mode**: Validate scripts without executing changes
- **Update Mode**: Incremental updates to existing schema without data loss

### Data Safety Features
- **Backup Validation**: Verify database backup exists before schema changes
- **Data Preservation**: Ensure existing data is preserved during schema updates
- **Rollback Scripts**: Generate rollback scripts for all changes
- **Change Logging**: Log all schema changes with timestamps and user information
- **Conflict Resolution**: Handle concurrent access and schema conflicts

## Enhanced Requirements

### 1. File Processing with Change Detection
- **Input**: Directory path with recursive scanning
- **Supported File Types**: .cs, .vb, .js, .ts, .py, .sql, .json, .config, .cshtml, .aspx
- **Change Detection**: File hash comparison for incremental processing
- **Git Integration**: Extract commit hash, branch, author information where available
- **Large File Handling**: Streaming processing for files > 50MB
- **Encoding Support**: UTF-8, UTF-16, ASCII with automatic detection

### 2. Advanced SQL Object Detection
- **Tables/Views**: Full schema.object.column pattern recognition
- **Stored Procedures**: Parameter extraction, return value analysis, nested procedure calls
- **Functions**: Scalar and table-valued functions with parameter mapping
- **Dynamic SQL**: Advanced parsing of sp_executesql and string concatenation patterns
- **CTEs and Subqueries**: Recursive analysis of complex query structures
- **Synonyms and Aliases**: Resolution of object aliases and synonyms

### 2.1. ADO.NET Specific Analysis
- **SqlCommand Objects**: Analyze CommandText property assignments
- **SqlDataAdapter**: Extract SelectCommand, InsertCommand, UpdateCommand, DeleteCommand
- **SqlConnection**: Identify connection string references and database names
- **SqlParameter**: Extract parameter names, types, and directions
- **CommandType**: Distinguish between Text, StoredProcedure, and TableDirect
- **ExecuteScalar/ExecuteReader/ExecuteNonQuery**: Method call analysis
- **DataSet/DataTable**: Table name mappings and schema references
- **SqlBulkCopy**: Destination table and column mappings
- **SqlTransaction**: Transaction scope analysis

### 2.2. Entity Framework Analysis
- **DbContext**: Entity mappings and table references
- **DbSet Properties**: Entity to table mappings
- **Raw SQL**: FromSqlRaw, ExecuteSqlRaw method calls
- **Stored Procedure Calls**: Database.ExecuteSqlRaw with procedure names
- **Entity Configurations**: Fluent API table and column mappings
- **Migration Files**: Up/Down method table operations

### 2.3. String-Based SQL Analysis
- **Embedded SQL**: SQL statements in string literals
- **String Concatenation**: Dynamic SQL construction patterns
- **StringBuilder**: SQL building using StringBuilder patterns
- **String Interpolation**: C# string interpolation with SQL
- **VB.NET String Handling**: VB-specific string concatenation patterns
- **Resource Files**: SQL statements in .resx files
- **Configuration SQL**: SQL in app.config, web.config, appsettings.json

### 3. Comprehensive ADO.NET Analysis
- **SqlCommand Lifecycle**: Creation, configuration, execution, disposal patterns
- **Connection Management**: Connection string analysis, pooling patterns, disposal tracking
- **Parameter Handling**: Type mapping, direction analysis, SQL injection risk assessment
- **Data Access Patterns**: Repository patterns, data layer architecture analysis
- **Performance Patterns**: Async/await usage, connection lifetime, command reuse
- **Error Handling**: Exception handling patterns around data access code

### 4. Column and Parameter Detection
- **Table/View Columns**: Specific column references in SELECT, WHERE, ORDER BY
- **Stored Procedure Parameters**: Input/output parameter identification
- **Function Parameters**: Parameter types and names
- **Dynamic SQL**: Parse dynamic SQL construction where possible

### 4.1. ADO.NET Parameter Analysis
- **SqlParameter Objects**: Name, SqlDbType, Direction, Size properties
- **Parameter Collections**: SqlCommand.Parameters.Add() calls
- **Parameter Binding**: @parameter name matching in SQL text
- **Output Parameters**: Direction = ParameterDirection.Output detection
- **Return Values**: Direction = ParameterDirection.ReturnValue detection
- **Parameter Values**: Literal value assignments where detectable

### 4.2. Advanced SQL Parsing
- **JOIN Analysis**: Table relationships and join conditions
- **Subquery Detection**: Nested SELECT statements
- **UNION Operations**: Multiple table combinations
- **WITH Clauses**: CTE definitions and references
- **Window Functions**: OVER clause analysis
- **Pivot/Unpivot**: Dynamic column operations
- **Bulk Operations**: MERGE, BULK INSERT statements

### 5. Entity Framework Deep Analysis
- **DbContext Analysis**: Entity mappings, configuration patterns, lifecycle management
- **Raw SQL Detection**: FromSqlRaw, ExecuteSqlRaw, FromSqlInterpolated patterns
- **Migration Analysis**: Schema change tracking, data migration patterns
- **Lazy Loading**: Navigation property analysis, N+1 query detection
- **Query Analysis**: LINQ to Entities translation patterns, performance implications

### 6. Code Structure Analysis
- **Namespace Mapping**: Full namespace hierarchy with SQL object associations
- **Class Dependencies**: SQL object usage per class with inheritance analysis
- **Method Granularity**: SQL object usage per method with call graph analysis
- **Design Pattern Detection**: Repository, Unit of Work, Factory patterns
- **Layered Architecture**: Data access layer identification and analysis

### 7. Database Integration Features
- **Connection Management**: Secure connection to target SQL Server instance
- **Schema Validation**: Verify referenced objects exist in target database
- **Performance Analysis**: Execution plan analysis for detected queries
- **Security Assessment**: Permission requirements analysis
- **Dependency Mapping**: Cross-object dependency analysis

### 8. Historical Analysis Capabilities
- **Baseline Comparison**: Compare current state to established baselines
- **Change Impact Analysis**: Assess impact of code changes on database dependencies
- **Trend Reporting**: Generate trend reports for management and architecture reviews
- **Regression Detection**: Identify reintroduction of deprecated patterns
- **Compliance Tracking**: Monitor adherence to coding standards over time

### 9. Advanced Configuration
- **Analysis Rules**: Configurable detection rules and patterns
- **Exclusion Patterns**: File, directory, and pattern exclusions
- **Custom Schemas**: Support for custom database schema mappings
- **Confidence Scoring**: Configurable confidence thresholds for different pattern types
- **Parallel Processing**: Multi-threaded analysis with configurable thread pools

### 10. Integration Capabilities
- **CI/CD Integration**: Command-line interface for build pipeline integration
- **Source Control**: Git integration for commit-based analysis
- **Reporting**: Export capabilities for external reporting tools
- **API Access**: REST API for integration with other tools
- **Alerting**: Configurable alerts for significant changes or violations

### 11. Performance and Scalability
- **Large Codebase Support**: Handle enterprise codebases with 100K+ files
- **Incremental Processing**: Process only changed files for faster analysis
- **Parallel Execution**: Multi-threaded processing with optimal resource utilization
- **Memory Management**: Efficient memory usage for large file processing
- **Database Performance**: Optimized queries and indexing strategy

## Output Specifications

### Database Schema Creation
```sql
-- Complete T-SQL scripts for table creation
-- Proper indexing strategy for optimal query performance
-- Foreign key relationships and constraints
-- Default values and computed columns
-- Retention policy implementation
```

### Analysis Views
```sql
-- Formatted views for common analysis scenarios
-- Parameterized views for flexible querying
-- Performance-optimized view definitions
-- Documentation and usage examples
```

### Sample Queries
```sql
-- Common analysis patterns
-- Historical comparison queries
-- Change detection queries
-- Trend analysis examples
-- Performance monitoring queries
```

### Reporting Templates
- Executive summary reports
- Technical debt analysis
- Architecture compliance reports
- Change impact assessments
- Risk analysis reports

## Technical Specifications

### Database Schema
```sql
-- Target view structure
CREATE VIEW vw_CodeAnalysis AS
SELECT 
    FilePath NVARCHAR(500),
    FileName NVARCHAR(255),
    FileExtension NVARCHAR(10),
    CodeBlockType NVARCHAR(50), -- Class, Method, Property, Function, etc.
    CodeBlockName NVARCHAR(255),
    LineNumber INT,
    SqlObjectType NVARCHAR(50), -- Table, View, StoredProcedure, Function, Parameter
    SchemaName NVARCHAR(128),
    ObjectName NVARCHAR(128),
    ColumnName NVARCHAR(128),
    ParameterName NVARCHAR(128),
    ParameterType NVARCHAR(50),
    ParameterDirection NVARCHAR(20), -- Input, Output, InputOutput, ReturnValue
    SqlStatement NVARCHAR(MAX), -- Full SQL statement when detectable
    AdoNetObjectType NVARCHAR(50), -- SqlCommand, SqlDataAdapter, SqlConnection, etc.
    AdoNetProperty NVARCHAR(100), -- CommandText, SelectCommand, etc.
    ConnectionStringName NVARCHAR(128),
    DatabaseName NVARCHAR(128),
    CommandType NVARCHAR(20), -- Text, StoredProcedure, TableDirect
    AnalysisTimestamp DATETIME2,
    SourceCodeSnippet NVARCHAR(1000), -- Context around the reference
    Confidence TINYINT, -- 1-100 confidence level of detection
    Notes NVARCHAR(500) -- Additional analysis notes
```

### Detection Patterns

#### C# Patterns
- `new SqlCommand("SELECT * FROM Users", connection)`
- `cmd.CommandText = "sp_GetUser"`
- `cmd.Parameters.Add("@UserId", SqlDbType.Int)`
- `context.Users.FromSqlRaw("SELECT * FROM Users WHERE Id = {0}", userId)`
- `await connection.QueryAsync<User>("sp_GetUsers")`

#### VB.NET Patterns
- `New SqlCommand("SELECT * FROM Users", connection)`
- `cmd.CommandText = "sp_GetUser"`
- `cmd.Parameters.Add("@UserId", SqlDbType.Int)`

#### Configuration File Patterns
- Connection strings in appsettings.json, web.config, app.config
- SQL statements in configuration sections
- Resource file SQL statements

#### JavaScript/TypeScript Patterns (for web applications)
- SQL in template literals
- AJAX calls to SQL-executing endpoints
- ORM query definitions

## Success Criteria

### Functional Requirements
- **Accuracy**: 95%+ accuracy in SQL object detection
- **Performance**: Process 10K files in under 5 minutes
- **Completeness**: Detect all major SQL object types and ADO.NET patterns
- **Reliability**: Handle processing errors gracefully without data corruption

### Non-Functional Requirements
- **Scalability**: Support codebases up to 100K files
- **Maintainability**: Clean, documented, extensible codebase
- **Security**: Secure handling of connection strings and sensitive data
- **Usability**: Clear documentation and intuitive command-line interface

### Quality Metrics
- **Code Coverage**: 90%+ test coverage for core functionality
- **Documentation**: Comprehensive README, API documentation, and examples
- **Error Handling**: Robust error handling with detailed logging
- **Performance**: Benchmark results for different codebase sizes
