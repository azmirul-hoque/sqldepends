# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a SQL Server Code Analysis Tool that analyzes source code files to identify SQL Server database object references, ADO.NET usage patterns, and Entity Framework mappings. The tool stores analysis results in SQL Server with historical tracking capabilities.

## Development Commands

### Python Environment Setup
```bash
# Install dependencies
pip install -r requirements.txt

# Run the main analyzer
python sql_analyzer.py --directory "C:\MyProject" --output "analysis_results.sql"

# Run with database integration
python sql_analyzer.py --directory "C:\MyProject" --server "localhost" --database "CodeAnalysis" --windows-auth

# Run with configuration file
python sql_analyzer.py --config config.json --directory "C:\MyProject"
```

### PowerShell Commands
```powershell
# Basic analysis
.\Analyze-SqlCode.ps1 -Directory "C:\MyProject" -OutputPath "analysis_results.sql"

# With database integration
.\Analyze-SqlCode.ps1 -Directory "C:\MyProject" -Server "localhost" -Database "CodeAnalysis" -UseWindowsAuth

# Generate report with verbose output
.\Analyze-SqlCode.ps1 -Directory "C:\MyProject" -OutputPath "analysis.sql" -GenerateReport -Verbose
```

### Database Schema Setup
```bash
# Create database schema automatically
python sql_analyzer.py --directory "C:\MyProject" --server "localhost" --database "CodeAnalysis" --windows-auth --create-schema --schema-file "sql\database_schema.sql" --views-file "sql\analysis_views.sql"

# Or execute manually in SSMS:
# 1. Execute sql/database_schema.sql
# 2. Execute sql/analysis_views.sql
```

## Architecture Overview

### Core Components

1. **sql_analyzer.py**: Main Python implementation with database connectivity via pyodbc
2. **Analyze-SqlCode.ps1**: PowerShell equivalent with SqlServer module integration
3. **config.json**: Configuration file for analysis settings, patterns, and database options
4. **sql/database_schema.sql**: Complete SQL Server schema for storing analysis results
5. **sql/analysis_views.sql**: Pre-built views for common analysis scenarios

### Key Classes and Functions

- **Config**: Configuration management from JSON file
- **SqlReference**: Data class representing a SQL object reference
- **SqlPatternAnalyzer**: Core analysis engine for pattern detection
- **DatabaseManager**: Database connectivity and schema management

### Database Integration

The tool supports both file export and direct database storage:
- **Live Database Mode**: Direct SQL Server connection with auto-schema creation
- **File Export Mode**: Generates SQL scripts for manual deployment
- **Hybrid Mode**: Both database storage and file export simultaneously

### Analysis Patterns

The tool detects:
- **ADO.NET patterns**: SqlCommand, SqlDataAdapter, SqlConnection, SqlParameter
- **Entity Framework**: DbContext, DbSet, FromSqlRaw, ExecuteSqlRaw
- **Dynamic SQL**: String concatenation, StringBuilder patterns
- **Configuration**: Connection strings in app.config, web.config, appsettings.json
- **Multi-language**: C#, VB.NET, JavaScript, TypeScript, Python, SQL files

## Critical Configuration

### WSL SQL Server Connection
When running from WSL, use the WSL host IP instead of localhost:
```bash
# Use WSL host IP for SQL Server connections
python sql_analyzer.py --server "172.31.208.1,14333" --database "CodeAnalysis" --username "sv" --password "YourPassword"
```

### Database Connection Examples
```json
{
  "connectionString": "Server=172.31.208.1,14333;Database=CodeAnalysis;User Id=sv;Password=YourPassword;TrustServerCertificate=true;"
}
```

## File Structure

```
sqldepends/
├── sql_analyzer.py           # Main Python analyzer
├── Analyze-SqlCode.ps1       # PowerShell implementation
├── config.json               # Configuration settings
├── requirements.txt          # Python dependencies
├── sql/
│   ├── database_schema.sql   # Database table definitions
│   └── analysis_views.sql    # Analysis views and queries
├── examples/
│   ├── sample_queries.sql    # Example analysis queries
│   └── usage_examples.md     # Command-line examples
└── docs/
    ├── README.md             # Main documentation
    ├── REQUIREMENTS.md       # Detailed requirements
    ├── PROJECT_STATUS.md     # Implementation status
    └── TODO.md               # Development roadmap
```

## Common Analysis Scenarios

### Basic Code Analysis
```bash
# Analyze .NET application
python sql_analyzer.py --directory "C:\MyWebApp" --include-extensions ".cs,.cshtml,.js" --exclude-dirs "bin,obj,wwwroot\lib"

# Analyze legacy VB.NET
python sql_analyzer.py --directory "C:\Legacy\VBApp" --include-extensions ".vb,.aspx,.ascx" --output "legacy_analysis.json" --format "json"
```

### Database Integration Analysis
```bash
# With object validation against live database
python sql_analyzer.py --directory "C:\Enterprise\Solutions" --server "prod-sql" --database "Enterprise" --validate-objects --parallel-processing
```

### Historical Analysis
```sql
-- View latest analysis results
SELECT * FROM CodeAnalysis.vw_LatestCodeAnalysis

-- See SQL object usage summary  
SELECT * FROM CodeAnalysis.vw_SqlObjectUsage

-- Check for changes between runs
SELECT * FROM CodeAnalysis.vw_CodeAnalysisChanges
```

## Development Guidelines

### Adding New Patterns
1. Update regex patterns in the `SqlPatternAnalyzer` class
2. Add corresponding test cases
3. Update configuration options in `config.json`
4. Document new patterns in the requirements

### Database Schema Changes
1. Update `sql/database_schema.sql` with new table structures
2. Update `sql/analysis_views.sql` with new view definitions
3. Test schema changes against existing data
4. Update migration procedures if needed

### Performance Considerations
- Use `--parallel-processing` for large codebases
- Configure `MaxDegreeOfParallelism` in config.json
- Exclude unnecessary directories (bin, obj, node_modules)
- Use incremental analysis for repeated runs on same codebase

## Testing

### Manual Testing
```bash
# Test with sample project
python sql_analyzer.py --directory "./examples" --output "test_results.sql" --dry-run

# Validate database connectivity
python sql_analyzer.py --server "localhost" --database "TestDB" --windows-auth --validate-connection
```

### Performance Testing
```bash
# Benchmark large codebase
python sql_analyzer.py --directory "C:\LargeProject" --parallel-processing --generate-statistics --log-level DEBUG
```

## Troubleshooting

### Common Issues
1. **Connection failures**: Verify SQL Server instance, authentication, and firewall settings
2. **Permission errors**: Ensure database create/write permissions
3. **Large file processing**: Increase memory allocation or use streaming mode
4. **Encoding issues**: Specify file encoding explicitly for non-UTF8 files

### Debug Mode
```bash
# Enable verbose logging
python sql_analyzer.py --directory "C:\MyProject" --log-level DEBUG --log-file "analysis.log"
```