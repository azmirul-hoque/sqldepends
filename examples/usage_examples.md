# Basic usage examples

## 1. Analyze local directory and export to SQL file
```bash
python sql_analyzer.py --directory "C:\MyProject" --output-file "analysis_results.sql"
```

## 2. Analyze and store in SQL Server database (Windows Auth)
```bash
python sql_analyzer.py --directory "C:\MyProject" --server "localhost" --database "CodeAnalysis" --windows-auth
```

## 3. Analyze with SQL Server authentication
```bash
python sql_analyzer.py --directory "C:\MyProject" --server "localhost" --database "CodeAnalysis" --username "sa" --password "MyPassword123"
```

## 4. Create database schema first
```bash
python sql_analyzer.py --directory "C:\MyProject" --server "localhost" --database "CodeAnalysis" --windows-auth --create-schema --schema-file "sql\database_schema.sql" --views-file "sql\analysis_views.sql"
```

## 5. Both database and file output
```bash
python sql_analyzer.py --directory "C:\MyProject" --server "localhost" --database "CodeAnalysis" --windows-auth --output-file "backup_analysis.sql"
```

## 6. Use custom configuration
```bash
python sql_analyzer.py --directory "C:\MyProject" --config-file "config.json" --output-file "analysis.sql"
```

## 7. Dry run to test configuration
```bash
python sql_analyzer.py --directory "C:\MyProject" --server "localhost" --database "CodeAnalysis" --windows-auth --dry-run
```

## 8. Incremental analysis (only changed files)
```bash
python sql_analyzer.py --directory "C:\MyProject" --server "localhost" --database "CodeAnalysis" --windows-auth --incremental
```

## 9. High performance analysis
```bash
python sql_analyzer.py --directory "C:\MyProject" --server "localhost" --database "CodeAnalysis" --windows-auth --parallel --max-workers 8
```

## 10. Debug mode with detailed logging
```bash
python sql_analyzer.py --directory "C:\MyProject" --output-file "analysis.sql" --log-level DEBUG --log-file "analysis.log"
```

# PowerShell Examples

## 1. Basic PowerShell analysis
```powershell
.\Analyze-SqlCode.ps1 -Directory "C:\MyProject" -OutputFile "analysis.sql"
```

## 2. PowerShell with database
```powershell
.\Analyze-SqlCode.ps1 -Directory "C:\MyProject" -Server "localhost" -Database "CodeAnalysis" -UseWindowsAuth
```

## 3. PowerShell with SQL auth
```powershell
.\Analyze-SqlCode.ps1 -Directory "C:\MyProject" -Server "localhost" -Database "CodeAnalysis" -Username "sa" -Password "MyPassword123"
```

# Advanced Scenarios

## Enterprise CI/CD Pipeline
```yaml
# Azure DevOps Pipeline
- task: PowerShell@2
  displayName: 'Analyze SQL Dependencies'
  inputs:
    targetType: 'filePath'
    filePath: '$(System.DefaultWorkingDirectory)/tools/Analyze-SqlCode.ps1'
    arguments: '-Directory "$(System.DefaultWorkingDirectory)" -Server "$(SqlServer)" -Database "$(AnalysisDatabase)" -UseWindowsAuth -CreateSchema'
```

## Batch Analysis
```bash
# Analyze multiple projects
for project in ProjectA ProjectB ProjectC; do
    python sql_analyzer.py --directory "/projects/$project" --server "localhost" --database "CodeAnalysis" --windows-auth
done
```

## Compliance Reporting
```bash
# Generate compliance report
python sql_analyzer.py --directory "C:\ComplianceProject" --server "localhost" --database "CodeAnalysis" --windows-auth --validate-objects
```
