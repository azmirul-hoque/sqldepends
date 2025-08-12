#Requires -Version 5.1

<#
.SYNOPSIS
    Complete MBox Platform SQL Analysis Script - PowerShell Edition
    
.DESCRIPTION
    Runs comprehensive analysis of ALL files in MBox Platform repository.
    Automatically scans the entire codebase, filters relevant files, and performs SQL dependency analysis.
    Optimized for Windows environments with PowerShell-native features.
    
.PARAMETER MBoxPath
    Path to the MBox Platform project directory
    
.PARAMETER OutputPath
    Custom output directory for analysis results
    
.PARAMETER SkipValidation
    Skip environment validation checks
    
.PARAMETER OpenResults
    Automatically open results folder after completion
    
.PARAMETER Verbose
    Enable verbose output for detailed logging
    
.EXAMPLE
    .\Run-MBoxAnalysisComplete.ps1
    
.EXAMPLE
    .\Run-MBoxAnalysisComplete.ps1 -MBoxPath "D:\Projects\mbox-platform" -OpenResults
    
.EXAMPLE
    .\Run-MBoxAnalysisComplete.ps1 -Verbose -OutputPath "C:\AnalysisResults"
    
.NOTES
    Author: SQLDepends Analysis Framework
    Version: 2.0.0
    Requires: PowerShell 5.1+, Python 3.8+
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$MBoxPath,
    
    [Parameter()]
    [string]$OutputPath,
    
    [Parameter()]
    [switch]$SkipValidation,
    
    [Parameter()]
    [switch]$OpenResults,
    
    [Parameter()]
    [switch]$GenerateExcel
)

# Platform detection and path configuration
function Initialize-PlatformPaths {
    # Get current working directory to help determine the right path approach
    $currentPath = (Get-Location).Path
    
    $platformWindows = $PSVersionTable.Platform -eq "Win32NT" -or $PSVersionTable.PSEdition -eq "Desktop" -or $env:OS -eq "Windows_NT"
    $platformLinux = $PSVersionTable.Platform -eq "Unix" -and $PSVersionTable.OS -like "*Linux*"
    $platformMacOS = $PSVersionTable.Platform -eq "Unix" -and $PSVersionTable.OS -like "*Darwin*"
    $platformWSL = $platformLinux -and (Test-Path "/mnt/c" -PathType Container)

    # Determine path style based on current directory
    $useWindowsPaths = $currentPath -match "^[A-Z]:" -or $currentPath -match "^\\\\.*"
    $useUnixPaths = $currentPath -match "^/" 

    Write-Verbose "Platform Detection: Windows=$platformWindows, Linux=$platformLinux, macOS=$platformMacOS, WSL=$platformWSL"
    Write-Verbose "Path Detection: Current=$currentPath, UseWindows=$useWindowsPaths, UseUnix=$useUnixPaths"

    # Determine base paths based on current directory style
    if ($useWindowsPaths) {
        $basePath = "D:\dev2"
        $separator = "\"
        $pythonCommand = if ($platformWindows) { "python" } else { "python3" }
    } elseif ($useUnixPaths) {
        $basePath = "/mnt/d/dev2"
        $separator = "/"
        $pythonCommand = "python3"
    } else {
        # Fallback based on platform
        if ($platformWindows) {
            $basePath = "D:\dev2"
            $separator = "\"
            $pythonCommand = "python"
        } else {
            $basePath = "/mnt/d/dev2"
            $separator = "/"
            $pythonCommand = "python3"
        }
    }

    return @{
        IsWindows = $platformWindows
        IsLinux = $platformLinux
        IsMacOS = $platformMacOS
        IsWSL = $platformWSL
        BasePath = $basePath
        Separator = $separator
        PythonCommand = $pythonCommand
        MBoxPath = Join-Path $basePath "mbox-platform"
        SqlDependsPath = Join-Path $basePath "sqldepends"
    }
}

# Initialize platform-specific configuration
$script:Platform = Initialize-PlatformPaths

# Initialize MBoxPath from parameter or platform default
$script:MBoxPath = if ($MBoxPath) { $MBoxPath } else { $script:Platform.MBoxPath }

# Configuration
$script:Config = @{
    SqlDependsPath = $script:Platform.SqlDependsPath
    Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    RunId = "mbox-analysis-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    PythonCommand = $script:Platform.PythonCommand
    RequiredScripts = @(
        "quick-sql-analyzer.py"
        "config-mbox-analysis.json"
    )
    # File extensions to include in analysis
    IncludeExtensions = @(
        ".cs", ".vb", ".sql", ".json", ".config", ".xml", 
        ".aspx", ".ascx", ".cshtml", ".vbhtml", ".js", ".ts"
    )
    # Directories to exclude from analysis
    ExcludeDirectories = @(
        "bin", "obj", "packages", "node_modules", ".vs", ".git", 
        "TestResults", "wwwroot/lib", "ClientApp/node_modules",
        "Release", "Debug", ".nuget", "artifacts"
    )
    # Patterns to exclude files
    ExcludePatterns = @(
        "*.min.js", "*.min.css", "*.dll", "*.pdb", "*.cache",
        "AssemblyInfo.cs", "*.g.cs", "*.designer.cs", "*.generated.cs"
    )
}

# Global variables for results
$script:Results = @{
    CopiedFiles = @()
    SkippedFiles = @()
    TotalFindings = 0
    SqlFindings = 0
    EfFindings = 0
    AdoFindings = 0
    AnalysisDir = ""
    ReportFile = ""
    StartTime = Get-Date
    TotalScanned = 0
}

#region Helper Functions

function Write-Banner {
    param([string]$Title, [string]$SubTitle = "")
    
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "           $Title" -ForegroundColor Cyan
    if ($SubTitle) {
        Write-Host "           $SubTitle" -ForegroundColor Magenta
    }
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "Run ID: $($script:Config.RunId)" -ForegroundColor Magenta
    Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Magenta
    Write-Host "Platform: $($script:Platform | ConvertTo-Json -Compress)" -ForegroundColor Gray
    Write-Host "================================================================" -ForegroundColor Cyan
}

function Write-Phase {
    param([string]$Message, [string]$Icon = "[*]")
    Write-Host "`n$Icon $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[-] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "[i] $Message" -ForegroundColor Cyan
}

function Test-Prerequisites {
    Write-Phase "Validating environment..." "[*]"
    
    $errors = 0
    
    # Set default MBoxPath if not provided
    if (-not $script:MBoxPath) {
        $script:MBoxPath = $script:Platform.MBoxPath
        Write-Info "Using platform-detected MBox path: $($script:MBoxPath)"
    }
    
    # Check MBox Platform
    if (-not (Test-Path $script:MBoxPath -PathType Container)) {
        Write-Error "MBox Platform not found at: $($script:MBoxPath)"
        Write-Info "Platform details: $($script:Platform | ConvertTo-Json)"
        $errors++
    } else {
        Write-Success "MBox Platform found at: $($script:MBoxPath)"
    }
    
    # Check SQLDepends tools
    if (-not (Test-Path $script:Config.SqlDependsPath -PathType Container)) {
        Write-Error "SQLDepends tools not found at: $($script:Config.SqlDependsPath)"
        $errors++
    } else {
        Write-Success "SQLDepends tools found"
    }
    
    # Check required scripts
    foreach ($script in $script:Config.RequiredScripts) {
        $scriptPath = Join-Path $script:Config.SqlDependsPath $script
        if (-not (Test-Path $scriptPath)) {
            Write-Error "Required script missing: $script"
            $errors++
        } else {
            Write-Success "Found: $script"
        }
    }
    
    # Check Python
    try {
        $pythonCmd = $script:Config.PythonCommand
        $pythonVersion = & $pythonCmd --version 2>$null
        if ($pythonVersion) {
            Write-Success "$pythonCmd available: $pythonVersion"
        } else {
            Write-Error "$pythonCmd not found"
            $errors++
        }
    } catch {
        Write-Error "$($script:Config.PythonCommand) not found or not accessible"
        $errors++
    }
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Error "PowerShell 5.1 or higher required. Current: $($PSVersionTable.PSVersion)"
        $errors++
    } else {
        Write-Success "PowerShell version: $($PSVersionTable.PSVersion)"
    }
    
    if ($errors -gt 0) {
        throw "Environment validation failed with $errors errors"
    }
    
    Write-Success "Environment validation passed"
}

function Initialize-AnalysisEnvironment {
    Write-Phase "Setting up analysis environment..." "[*]"
    
    # Navigate to sqldepends directory
    Push-Location $script:Config.SqlDependsPath
    
    # Create analysis directories
    if ($OutputPath) {
        $analysisDir = Join-Path $OutputPath $script:Config.RunId
    } else {
        $analysisDir = Join-Path "analysis-output" "mbox-platform" $script:Config.RunId
    }
    
    $inputDir = Join-Path "analysis-input" "mbox-$($script:Config.RunId)"
    
    # Create directories
    $null = New-Item -Path $analysisDir -ItemType Directory -Force
    $null = New-Item -Path $inputDir -ItemType Directory -Force
    $null = New-Item -Path "logs" -ItemType Directory -Force -ErrorAction SilentlyContinue
    
    Write-Success "Analysis directories created"
    Write-Host "  Input: $inputDir" -ForegroundColor Gray
    Write-Host "  Output: $analysisDir" -ForegroundColor Gray
    
    # Store paths for later use
    $script:Results.AnalysisDir = $analysisDir
    $script:InputDir = $inputDir
    
    return @{
        AnalysisDir = $analysisDir
        InputDir = $inputDir
    }
}

function Copy-AnalysisFiles {
    Write-Phase "Scanning all files in mbox-platform for comprehensive analysis..." "[*]"
    
    $copiedFiles = @()
    $skippedFiles = @()
    $totalScanned = 0
    
    Write-Info "Discovering files in: $($script:MBoxPath)"
    
    # Get all files recursively
    $allFiles = Get-ChildItem -Path $script:MBoxPath -Recurse -File -ErrorAction SilentlyContinue
    
    foreach ($file in $allFiles) {
        $totalScanned++
        
        # Get proper relative path using Resolve-Path with -Relative
        try {
            Push-Location $script:MBoxPath
            $relativePath = Resolve-Path -Path $file.FullName -Relative -ErrorAction Stop
            $relativePath = $relativePath.TrimStart('.\', './')
            Pop-Location
        } catch {
            # Fallback method if Resolve-Path fails
            $relativePath = $file.FullName.Substring($script:MBoxPath.Length).TrimStart('\', '/')
            Pop-Location -ErrorAction SilentlyContinue
        }
        
        # Check if file extension is included
        $extension = $file.Extension.ToLower()
        if ($extension -notin $script:Config.IncludeExtensions) {
            continue
        }
        
        # Check if file is in excluded directory
        $inExcludedDir = $false
        foreach ($excludeDir in $script:Config.ExcludeDirectories) {
            if ($relativePath -like "*$excludeDir*") {
                $inExcludedDir = $true
                break
            }
        }
        if ($inExcludedDir) {
            $skippedFiles += $relativePath
            continue
        }
        
        # Check if file matches excluded patterns
        $matchesExcludedPattern = $false
        foreach ($pattern in $script:Config.ExcludePatterns) {
            if ($file.Name -like $pattern) {
                $matchesExcludedPattern = $true
                break
            }
        }
        if ($matchesExcludedPattern) {
            $skippedFiles += $relativePath
            continue
        }
        
        try {
            # Create directory structure - ensure we use proper path separators
            $relativeDir = Split-Path $relativePath -Parent
            if ($relativeDir) {
                $targetDir = Join-Path $script:InputDir $relativeDir
                if (-not (Test-Path $targetDir)) {
                    $null = New-Item -Path $targetDir -ItemType Directory -Force -ErrorAction Stop
                }
            }
            
            # Copy file with proper path handling
            $targetPath = Join-Path $script:InputDir $relativePath
            Copy-Item -Path $file.FullName -Destination $targetPath -Force -ErrorAction Stop
            $copiedFiles += $relativePath
            
            if ($copiedFiles.Count % 50 -eq 0) {
                Write-Host "  Progress: $($copiedFiles.Count) files copied..." -ForegroundColor Gray
            }
        } catch {
            Write-Warning "Failed to copy: $($file.FullName) -> $relativePath - $($_.Exception.Message)"
            $skippedFiles += $relativePath
        }
    }
    
    Write-Host "`n[DISCOVERY] File Discovery Summary:" -ForegroundColor Green
    Write-Host "  Total files scanned: $totalScanned" -ForegroundColor Cyan
    Write-Host "  Files copied for analysis: $($copiedFiles.Count)" -ForegroundColor Green
    Write-Host "  Files skipped (filters): $($skippedFiles.Count)" -ForegroundColor Yellow
    
    # Group files by extension for reporting
    $filesByExtension = $copiedFiles | Group-Object { [System.IO.Path]::GetExtension($_).ToLower() } | Sort-Object Name
    Write-Host "`n[BREAKDOWN] Files by Extension:" -ForegroundColor Green
    foreach ($group in $filesByExtension) {
        Write-Host "  $($group.Name): $($group.Count) files" -ForegroundColor Cyan
    }
    
    # Store results
    $script:Results.CopiedFiles = $copiedFiles
    $script:Results.MissingFiles = @()  # Not applicable for full scan
    $script:Results.SkippedFiles = $skippedFiles
    
    # Save file lists
    $copiedFiles | Out-File -FilePath (Join-Path $script:Results.AnalysisDir "copied-files.txt") -Encoding UTF8
    $skippedFiles | Out-File -FilePath (Join-Path $script:Results.AnalysisDir "skipped-files.txt") -Encoding UTF8
    
    # Save file breakdown by extension
    $filesByExtension | ForEach-Object { "$($_.Name): $($_.Count)" } | Out-File -FilePath (Join-Path $script:Results.AnalysisDir "files-by-extension.txt") -Encoding UTF8
    
    return @{
        CopiedCount = $copiedFiles.Count
        SkippedCount = $skippedFiles.Count
        TotalScanned = $totalScanned
    }
}

function Invoke-Analysis {
    Write-Phase "Running SQL dependency analysis..." "[*]"
    
    $outputFile = Join-Path $script:Results.AnalysisDir "mbox-complete-analysis.sql"
    $jsonOutput = Join-Path $script:Results.AnalysisDir "mbox-complete-analysis.json"
    $logFile = Join-Path "logs" "mbox-complete-$($script:Config.Timestamp).log"
    
    Write-Host "Analysis files:"
    Write-Host "  SQL Output: $outputFile" -ForegroundColor Gray
    Write-Host "  JSON Output: $jsonOutput" -ForegroundColor Gray
    Write-Host "  Log File: $logFile" -ForegroundColor Gray
    
    try {
        # Run SQL analysis
        Write-Info "Running SQL pattern analysis..."
        $sqlArgs = @(
            "quick-sql-analyzer.py"
            "--directory", $script:InputDir
            "--output", $outputFile
            "--format", "sql"
        )
        
        $pythonCmd = $script:Config.PythonCommand
        $sqlOutput = & $pythonCmd @sqlArgs 2>&1
        $sqlOutput | Out-File -FilePath $logFile -Encoding UTF8
        $sqlExitCode = $LASTEXITCODE
        
        # Run JSON analysis
        Write-Info "Running JSON analysis for detailed data..."
        $jsonArgs = @(
            "quick-sql-analyzer.py"
            "--directory", $script:InputDir
            "--output", $jsonOutput
            "--format", "json"
        )
        
        $jsonOutput = & $pythonCmd @jsonArgs 2>&1
        $jsonExitCode = $LASTEXITCODE
        
        if ($sqlExitCode -eq 0 -and $jsonExitCode -eq 0) {
            Write-Success "Analysis completed successfully"
            
            # Extract statistics from JSON
            $jsonFilePath = Join-Path $script:Results.AnalysisDir "mbox-complete-analysis.json"
            Write-Host "`n[PARSE] Parsing analysis results from JSON..." -ForegroundColor Yellow
            Write-Host "  JSON file: $jsonFilePath" -ForegroundColor Gray
            
            if (Test-Path $jsonFilePath) {
                try {
                    $jsonContent = Get-Content $jsonFilePath -Raw
                    Write-Host "  JSON file size: $($jsonContent.Length) characters" -ForegroundColor Gray
                    
                    $jsonData = $jsonContent | ConvertFrom-Json
                    Write-Host "  JSON parsed successfully" -ForegroundColor Green
                    
                    # Debug: Show JSON structure
                    Write-Host "  JSON structure: $($jsonData | ConvertTo-Json -Depth 2 -Compress)" -ForegroundColor Gray
                    
                    # Extract findings with better error handling
                    $script:Results.TotalFindings = if ($jsonData.total_findings) { $jsonData.total_findings } else { 0 }
                    $script:Results.SqlFindings = if ($jsonData.summary -and $jsonData.summary.sql_statements) { $jsonData.summary.sql_statements } else { 0 }
                    $script:Results.EfFindings = if ($jsonData.summary -and $jsonData.summary.entity_framework) { $jsonData.summary.entity_framework } else { 0 }
                    $script:Results.AdoFindings = if ($jsonData.summary -and $jsonData.summary.ado_net) { $jsonData.summary.ado_net } else { 0 }
                    
                    Write-Host "`n[RESULTS] Analysis Results Extracted:" -ForegroundColor Green
                    Write-Host "  Total findings: $($script:Results.TotalFindings)" -ForegroundColor Cyan
                    Write-Host "  SQL statements: $($script:Results.SqlFindings)" -ForegroundColor Cyan
                    Write-Host "  Entity Framework: $($script:Results.EfFindings)" -ForegroundColor Cyan
                    Write-Host "  ADO.NET: $($script:Results.AdoFindings)" -ForegroundColor Cyan
                } catch {
                    Write-Warning "Could not parse JSON results for statistics: $($_.Exception.Message)"
                    Write-Host "  JSON content preview: $($jsonContent.Substring(0, [Math]::Min(200, $jsonContent.Length)))" -ForegroundColor Red
                }
            } else {
                Write-Warning "JSON results file not found at: $jsonFilePath"
            }
            
            return $true
        } else {
            Write-Error "Analysis failed"
            Write-Host "  SQL analysis exit code: $sqlExitCode" -ForegroundColor Red
            Write-Host "  JSON analysis exit code: $jsonExitCode" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Error "Analysis execution failed: $($_.Exception.Message)"
        return $false
    }
}

function New-AnalysisReport {
    Write-Phase "Generating comprehensive report..." "[*]"
    
    $reportFile = Join-Path $script:Results.AnalysisDir "MBOX-ANALYSIS-REPORT-$($script:Config.Timestamp).md"
    $script:Results.ReportFile = $reportFile
    
    $executionTime = (Get-Date) - $script:Results.StartTime
    
    $reportContent = @"
# MBox Platform SQL Analysis Report

**Generated:** $(Get-Date)  
**Run ID:** $($script:Config.RunId)  
**Analysis Tool:** sqldepends v2.0.0 (PowerShell Edition)  
**Execution Mode:** Comprehensive full-repository scan  
**Execution Time:** $($executionTime.ToString("hh\:mm\:ss"))  

## Executive Summary

This automated analysis scanned **$($script:Results.TotalScanned) total files** from the MBox Platform project repository and analyzed **$($script:Results.CopiedFiles.Count) relevant files** to identify SQL dependencies, Entity Framework usage, and ADO.NET patterns.

## Analysis Statistics

- **Total Files Scanned:** $($script:Results.TotalScanned)
- **Files Analyzed:** $($script:Results.CopiedFiles.Count)
- **Files Skipped:** $($script:Results.SkippedFiles.Count)
- **Total Findings:** $($script:Results.TotalFindings)
- **SQL Statements:** $($script:Results.SqlFindings)
- **Entity Framework References:** $($script:Results.EfFindings)
- **ADO.NET References:** $($script:Results.AdoFindings)

## Analysis Scope

### Included File Types
$(($script:Config.IncludeExtensions | ForEach-Object { "- $_" }) -join "`n")

### Excluded Directories
$(($script:Config.ExcludeDirectories | ForEach-Object { "- $_" }) -join "`n")

### Excluded File Patterns
$(($script:Config.ExcludePatterns | ForEach-Object { "- $_" }) -join "`n")

## Files Analyzed

### Successfully Processed ($($script:Results.CopiedFiles.Count) files)
"@

    # Add copied files
    foreach ($file in $script:Results.CopiedFiles) {
        $reportContent += "`n- $file"
    }
    
    # Add skipped files summary if any
    if ($script:Results.SkippedFiles.Count -gt 0) {
        $reportContent += "`n`n### Files Skipped Due to Filters ($($script:Results.SkippedFiles.Count) files)"
        $reportContent += "`n*Note: Detailed list available in skipped-files.txt*"
        
        # Show first few examples
        $exampleCount = [Math]::Min(10, $script:Results.SkippedFiles.Count)
        for ($i = 0; $i -lt $exampleCount; $i++) {
            $reportContent += "`n- $($script:Results.SkippedFiles[$i])"
        }
        if ($script:Results.SkippedFiles.Count -gt 10) {
            $reportContent += "`n- ... and $($script:Results.SkippedFiles.Count - 10) more files"
        }
    }
    
    $reportContent += @"

## Key Findings

$(if ($script:Results.EfFindings -gt 0) { "[+] **Entity Framework Usage Detected** - $($script:Results.EfFindings) references found" })
$(if ($script:Results.SqlFindings -gt 0) { "[+] **Direct SQL Usage Detected** - $($script:Results.SqlFindings) statements found" })
$(if ($script:Results.AdoFindings -gt 0) { "[+] **ADO.NET Usage Detected** - $($script:Results.AdoFindings) references found" })

## Recommendations

### Immediate Actions
1. Review detailed findings in the SQL and JSON output files
2. Audit any raw SQL usage for security vulnerabilities
3. Validate Entity Framework query performance patterns
4. Check connection string security practices

### Next Steps
1. Expand analysis to include configuration files
2. Review database migration patterns
3. Analyze stored procedure usage
4. Performance testing of identified query patterns

## Output Files

- **SQL Analysis:** mbox-complete-analysis.sql
- **JSON Data:** mbox-complete-analysis.json
- **Execution Log:** ../../../logs/mbox-complete-$($script:Config.Timestamp).log
- **This Report:** $(Split-Path $reportFile -Leaf)

## PowerShell Specific Features

### Environment Information
- **PowerShell Version:** $($PSVersionTable.PSVersion)
- **OS Version:** $($PSVersionTable.OS)
- **Execution Policy:** $(Get-ExecutionPolicy)
- **Current User:** $($env:USERNAME)
- **Computer Name:** $($env:COMPUTERNAME)

### Performance Metrics
- **Analysis Duration:** $($executionTime.ToString("hh\:mm\:ss"))
- **Files Processed per Second:** $([math]::Round($script:Results.CopiedFiles.Count / $executionTime.TotalSeconds, 2))
- **Findings per File:** $([math]::Round($script:Results.TotalFindings / $script:Results.CopiedFiles.Count, 2))

## Analysis Methodology

### Safety Measures
[+] Read-only analysis - No modifications to source code  
[+] Isolated execution - All analysis in separate directory  
[+] Automated file selection - Consistent target files  
[+] Comprehensive logging - Full execution trace  
[+] PowerShell error handling - Graceful failure management  

### Tool Configuration
- **Pattern Detection:** SQL statements, Entity Framework, ADO.NET
- **File Types:** C# source files (.cs)
- **Exclusions:** Build artifacts, temporary files, auto-generated code
- **Analysis Engine:** quick-sql-analyzer.py with PowerShell orchestration

---

**Analysis completed successfully at $(Get-Date)**  
*Report generated by automated MBox Platform analysis script (PowerShell Edition)*
"@

    # Write report
    $reportContent | Out-File -FilePath $reportFile -Encoding UTF8
    
    Write-Success "Report generated: $(Split-Path $reportFile -Leaf)"
}

function Get-DatabaseObjectsFromCode {
    param(
        [string]$CodeContext,
        [string]$FindingType
    )
    
    if (-not $CodeContext) {
        return @{
            Objects = ''
            Types = ''
            Schemas = ''
            Primary = ''
        }
    }
    
    $objects = @()
    $objectTypes = @()
    $schemas = @()
    
    try {
        # Remove common code noise for better SQL parsing
        $cleanCode = $CodeContext -replace '\\n', ' ' -replace '\\t', ' ' -replace '\s+', ' '
        
        # Entity Framework specific patterns
        if ($FindingType -like "*Entity*" -or $FindingType -like "*EF*") {
            # DbSet<Entity> patterns
            if ($cleanCode -match 'DbSet<(\w+)>') {
                $objects += $Matches[1]
                $objectTypes += 'Table/Entity'
            }
            
            # FromSqlRaw/ExecuteSqlRaw with table references
            if ($cleanCode -match 'FromSqlRaw.*?".*?FROM\s+(\w+\.?\w*)"' -or $cleanCode -match "FromSqlRaw.*?'.*?FROM\s+(\w+\.?\w*)'") {
                $objects += $Matches[1]
                $objectTypes += 'Table'
            }
            
            # Entity class names in context
            if ($cleanCode -match '\.(\w+)\.Add\(' -or $cleanCode -match '\.(\w+)\.Update\(' -or $cleanCode -match '\.(\w+)\.Remove\(') {
                $objects += $Matches[1]
                $objectTypes += 'Table/Entity'
            }
        }
        
        # Direct SQL patterns
        elseif ($FindingType -like "*SQL*" -or $FindingType -like "*Query*") {
            # Table references in SELECT/INSERT/UPDATE/DELETE
            $sqlPatterns = @(
                'FROM\s+(\[?\w+\]?\.?\[?\w+\]?)',
                'JOIN\s+(\[?\w+\]?\.?\[?\w+\]?)',
                'UPDATE\s+(\[?\w+\]?\.?\[?\w+\]?)',
                'INSERT\s+INTO\s+(\[?\w+\]?\.?\[?\w+\]?)',
                'DELETE\s+FROM\s+(\[?\w+\]?\.?\[?\w+\]?)'
            )
            
            foreach ($pattern in $sqlPatterns) {
                if ($cleanCode -match $pattern) {
                    $tableName = $Matches[1] -replace '[\[\]]', ''
                    $objects += $tableName
                    $objectTypes += 'Table'
                    
                    # Extract schema if present
                    if ($tableName -match '^(\w+)\.(\w+)$') {
                        $schemas += $Matches[1]
                    }
                }
            }
            
            # Stored procedure calls
            if ($cleanCode -match 'EXEC\s+(\[?\w+\]?\.?\[?\w+\]?)' -or $cleanCode -match 'EXECUTE\s+(\[?\w+\]?\.?\[?\w+\]?)') {
                $procName = $Matches[1] -replace '[\[\]]', ''
                $objects += $procName
                $objectTypes += 'Stored Procedure'
                
                if ($procName -match '^(\w+)\.(\w+)$') {
                    $schemas += $Matches[1]
                }
            }
            
            # Function calls
            if ($cleanCode -match '(\w+\.\w+)\(' -and $cleanCode -notmatch 'Console\.|String\.|DateTime\.') {
                $funcName = $Matches[1]
                $objects += $funcName
                $objectTypes += 'Function'
                
                if ($funcName -match '^(\w+)\.(\w+)$') {
                    $schemas += $Matches[1]
                }
            }
        }
        
        # ADO.NET specific patterns
        elseif ($FindingType -like "*ADO*") {
            # SqlCommand with CommandText
            if ($cleanCode -match 'CommandText\s*=\s*"([^"]+)"') {
                $sqlText = $Matches[1]
                # Recursively parse the SQL text
                $nestedObjects = Get-DatabaseObjectsFromCode -CodeContext $sqlText -FindingType "SQL Query"
                if ($nestedObjects.Objects) {
                    $objects += $nestedObjects.Objects -split ', '
                    $objectTypes += $nestedObjects.Types -split ', '
                    $schemas += $nestedObjects.Schemas -split ', '
                }
            }
            elseif ($cleanCode -match "CommandText\s*=\s*'([^']+)'") {
                $sqlText = $Matches[1]
                # Recursively parse the SQL text
                $nestedObjects = Get-DatabaseObjectsFromCode -CodeContext $sqlText -FindingType "SQL Query"
                if ($nestedObjects.Objects) {
                    $objects += $nestedObjects.Objects -split ', '
                    $objectTypes += $nestedObjects.Types -split ', '
                    $schemas += $nestedObjects.Schemas -split ', '
                }
            }
            
            # SqlCommand constructor with SQL
            if ($cleanCode -match 'new SqlCommand\s*\(\s*"([^"]+)"') {
                $sqlText = $Matches[1]
                $nestedObjects = Get-DatabaseObjectsFromCode -CodeContext $sqlText -FindingType "SQL Query"
                if ($nestedObjects.Objects) {
                    $objects += $nestedObjects.Objects -split ', '
                    $objectTypes += $nestedObjects.Types -split ', '
                    $schemas += $nestedObjects.Schemas -split ', '
                }
            }
            elseif ($cleanCode -match "new SqlCommand\s*\(\s*'([^']+)'") {
                $sqlText = $Matches[1]
                $nestedObjects = Get-DatabaseObjectsFromCode -CodeContext $sqlText -FindingType "SQL Query"
                if ($nestedObjects.Objects) {
                    $objects += $nestedObjects.Objects -split ', '
                    $objectTypes += $nestedObjects.Types -split ', '
                    $schemas += $nestedObjects.Schemas -split ', '
                }
            }
        }
        
        # Connection String analysis
        elseif ($FindingType -like "*Connection*") {
            if ($cleanCode -match 'Database=([^;]+)' -or $cleanCode -match 'Initial Catalog=([^;]+)') {
                $objects += $Matches[1]
                $objectTypes += 'Database'
            }
            
            if ($cleanCode -match 'Server=([^;]+)' -or $cleanCode -match 'Data Source=([^;]+)') {
                $objects += $Matches[1]
                $objectTypes += 'Server'
            }
        }
        
        # Generic table/object name patterns (fallback)
        else {
            # Look for common SQL keywords followed by identifiers
            $genericPatterns = @(
                '\bFROM\s+(\w+)',
                '\bINTO\s+(\w+)',
                '\bUPDATE\s+(\w+)',
                '\bTABLE\s+(\w+)'
            )
            
            foreach ($pattern in $genericPatterns) {
                if ($cleanCode -match $pattern) {
                    $objects += $Matches[1]
                    $objectTypes += 'Table'
                }
            }
        }
        
        # Remove duplicates and clean up
        $objects = $objects | Select-Object -Unique | Where-Object { $_ -and $_.Trim() -ne '' }
        $objectTypes = $objectTypes | Select-Object -Unique | Where-Object { $_ -and $_.Trim() -ne '' }
        $schemas = $schemas | Select-Object -Unique | Where-Object { $_ -and $_.Trim() -ne '' }
        
        return @{
            Objects = ($objects -join ', ')
            Types = ($objectTypes -join ', ')
            Schemas = ($schemas -join ', ')
            Primary = if ($objects.Count -gt 0) { $objects[0] } else { '' }
        }
    }
    catch {
        Write-Verbose "Error parsing database objects from code: $($_.Exception.Message)"
        return @{
            Objects = ''
            Types = ''
            Schemas = ''
            Primary = ''
        }
    }
}

function New-ExcelReport {
    param([switch]$Force)
    
    if (-not $GenerateExcel -and -not $Force) {
        return
    }
    
    Write-Phase "Generating comprehensive Excel report..." "[*]"
    
    try {
        # Check if ImportExcel module is available
        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
            Write-Warning "ImportExcel module not found. Installing..."
            Install-Module -Name ImportExcel -Force -Scope CurrentUser
        }
        
        Import-Module ImportExcel
        
        $excelFile = Join-Path $script:Results.AnalysisDir "MBOX-ANALYSIS-$($script:Config.Timestamp).xlsx"
        
        # Debug: Show current findings values
        Write-Host "  Debug - Current findings: Total=$($script:Results.TotalFindings), SQL=$($script:Results.SqlFindings), EF=$($script:Results.EfFindings), ADO=$($script:Results.AdoFindings)" -ForegroundColor Gray
        
        # Summary worksheet with execution details
        $summaryData = @()
        $summaryData += [PSCustomObject]@{ 'Metric' = 'Run ID'; 'Value' = $script:Config.RunId }
        $summaryData += [PSCustomObject]@{ 'Metric' = 'Execution Time'; 'Value' = ((Get-Date) - $script:Results.StartTime).ToString("hh\:mm\:ss") }
        $summaryData += [PSCustomObject]@{ 'Metric' = 'Total Files Scanned'; 'Value' = $script:Results.TotalScanned }
        $summaryData += [PSCustomObject]@{ 'Metric' = 'Files Analyzed'; 'Value' = $script:Results.CopiedFiles.Count }
        $summaryData += [PSCustomObject]@{ 'Metric' = 'Files Skipped'; 'Value' = $script:Results.SkippedFiles.Count }
        $summaryData += [PSCustomObject]@{ 'Metric' = 'Total Findings'; 'Value' = $script:Results.TotalFindings }
        $summaryData += [PSCustomObject]@{ 'Metric' = 'SQL Statements'; 'Value' = $script:Results.SqlFindings }
        $summaryData += [PSCustomObject]@{ 'Metric' = 'Entity Framework'; 'Value' = $script:Results.EfFindings }
        $summaryData += [PSCustomObject]@{ 'Metric' = 'ADO.NET'; 'Value' = $script:Results.AdoFindings }
        
        $summaryData | Export-Excel -Path $excelFile -WorksheetName "Summary" -AutoSize -BoldTopRow -TableStyle Medium2
        
        # Files by Category worksheet
        $filesData = $script:Results.CopiedFiles | ForEach-Object {
            $category = if ($_ -like "*Infrastructure*") { "Infrastructure" } 
                       elseif ($_ -like "*Services*") { "Services" }
                       elseif ($_ -like "*Events*") { "Events" }
                       elseif ($_ -like "*Host.Api*") { "API" }
                       elseif ($_ -like "*Host.Functions*") { "Functions" }
                       elseif ($_ -like "*Host.Identity*") { "Identity" }
                       elseif ($_ -like "*Platform.Data*") { "Data" }
                       elseif ($_ -like "*Platform.Domain*") { "Domain" }
                       else { "Other" }
            
            [PSCustomObject]@{
                'File Path' = $_
                'File Name' = Split-Path $_ -Leaf
                'Extension' = [System.IO.Path]::GetExtension($_)
                'Category' = $category
                'Directory' = Split-Path $_ -Parent
                'Status' = 'Analyzed'
            }
        }
        
        $filesData | Export-Excel -Path $excelFile -WorksheetName "Files" -AutoSize -BoldTopRow -TableStyle Medium6
        
        # File Type Breakdown worksheet
        $fileTypeData = $script:Results.CopiedFiles | 
            Group-Object { [System.IO.Path]::GetExtension($_).ToLower() } | 
            ForEach-Object {
                [PSCustomObject]@{
                    'Extension' = if ($_.Name) { $_.Name } else { '(no extension)' }
                    'Count' = $_.Count
                    'Percentage' = [math]::Round(($_.Count / $script:Results.CopiedFiles.Count) * 100, 2)
                }
            } | Sort-Object Count -Descending
        
        $fileTypeData | Export-Excel -Path $excelFile -WorksheetName "FileTypes" -AutoSize -BoldTopRow -TableStyle Medium4
        
        # Category Breakdown worksheet
        $categoryData = $filesData | 
            Group-Object Category | 
            ForEach-Object {
                [PSCustomObject]@{
                    'Category' = $_.Name
                    'Files Count' = $_.Count
                    'Percentage' = [math]::Round(($_.Count / $script:Results.CopiedFiles.Count) * 100, 2)
                }
            } | Sort-Object 'Files Count' -Descending
        
        $categoryData | Export-Excel -Path $excelFile -WorksheetName "Categories" -AutoSize -BoldTopRow -TableStyle Medium8
        
        # Configuration worksheet
        $configData = @()
        $configData += [PSCustomObject]@{ 'Setting' = 'MBox Path'; 'Value' = $script:MBoxPath }
        $configData += [PSCustomObject]@{ 'Setting' = 'SQLDepends Path'; 'Value' = $script:Config.SqlDependsPath }
        $configData += [PSCustomObject]@{ 'Setting' = 'Python Command'; 'Value' = $script:Config.PythonCommand }
        $configData += [PSCustomObject]@{ 'Setting' = 'Platform'; 'Value' = "$($script:Platform.IsWindows ? 'Windows' : $script:Platform.IsLinux ? 'Linux' : 'Other')" }
        $configData += [PSCustomObject]@{ 'Setting' = 'PowerShell Version'; 'Value' = $PSVersionTable.PSVersion.ToString() }
        
        foreach ($ext in $script:Config.IncludeExtensions) {
            $configData += [PSCustomObject]@{ 'Setting' = 'Include Extension'; 'Value' = $ext }
        }
        
        $configData | Export-Excel -Path $excelFile -WorksheetName "Configuration" -AutoSize -BoldTopRow -TableStyle Light1
        
        # SQL Dependencies worksheet - Parse JSON findings
        try {
            $jsonFilePath = Join-Path $script:Results.AnalysisDir "mbox-complete-analysis.json"
            if (Test-Path $jsonFilePath) {
                Write-Host "  Processing SQL dependency findings..." -ForegroundColor Gray
                
                $jsonContent = Get-Content $jsonFilePath -Raw | ConvertFrom-Json
                $sqlDependencies = @()
                
                # Process findings from JSON
                if ($jsonContent.findings -and $jsonContent.findings.Count -gt 0) {
                    foreach ($finding in $jsonContent.findings) {
                        # Extract database objects from code context
                        $codeContext = if ($finding.context) { $finding.context } else { $finding.code }
                        $databaseObjects = Get-DatabaseObjectsFromCode -CodeContext $codeContext -FindingType $finding.type
                        
                        $sqlDependencies += [PSCustomObject]@{
                            'File' = $finding.file
                            'Line' = $finding.line_number
                            'Type' = $finding.type
                            'Category' = $finding.category
                            'Pattern' = $finding.pattern
                            'Code Context' = $codeContext
                            'Database Objects' = $databaseObjects.Objects
                            'Object Types' = $databaseObjects.Types
                            'Schema References' = $databaseObjects.Schemas
                            'SQL Object' = if ($finding.sql_object) { $finding.sql_object } else { $databaseObjects.Primary }
                            'Description' = if ($finding.description) { $finding.description } else { $finding.type }
                            'Confidence' = if ($finding.confidence) { $finding.confidence } else { 'Medium' }
                        }
                    }
                } elseif ($jsonContent.results -and $jsonContent.results.Count -gt 0) {
                    # Alternative JSON structure
                    foreach ($result in $jsonContent.results) {
                        if ($result.findings) {
                            foreach ($finding in $result.findings) {
                                # Extract database objects from code context
                                $codeContext = $finding.context
                                $databaseObjects = Get-DatabaseObjectsFromCode -CodeContext $codeContext -FindingType $finding.type
                                
                                $sqlDependencies += [PSCustomObject]@{
                                    'File' = $result.file
                                    'Line' = $finding.line
                                    'Type' = $finding.type
                                    'Category' = $finding.category
                                    'Pattern' = $finding.pattern_match
                                    'Code Context' = $codeContext
                                    'Database Objects' = $databaseObjects.Objects
                                    'Object Types' = $databaseObjects.Types
                                    'Schema References' = $databaseObjects.Schemas
                                    'SQL Object' = if ($finding.referenced_object) { $finding.referenced_object } else { $databaseObjects.Primary }
                                    'Description' = $finding.description
                                    'Confidence' = if ($finding.confidence) { $finding.confidence } else { 'Medium' }
                                }
                            }
                        }
                    }
                } else {
                    # Fallback: Create sample entries if no detailed findings
                    Write-Host "  No detailed findings structure found, creating summary entries..." -ForegroundColor Yellow
                    
                    if ($script:Results.SqlFindings -gt 0) {
                        $sqlDependencies += [PSCustomObject]@{
                            'File' = 'Multiple Files'
                            'Line' = ''
                            'Type' = 'SQL Statement'
                            'Category' = 'Direct SQL'
                            'Pattern' = 'Various SQL patterns'
                            'Code Context' = "Found $($script:Results.SqlFindings) SQL statements"
                            'Database Objects' = 'Tables, Views, Procedures (See detailed analysis)'
                            'Object Types' = 'Mixed'
                            'Schema References' = 'Various schemas'
                            'SQL Object' = 'Various'
                            'Description' = 'SQL statements detected in codebase'
                            'Confidence' = 'High'
                        }
                    }
                    
                    if ($script:Results.EfFindings -gt 0) {
                        $sqlDependencies += [PSCustomObject]@{
                            'File' = 'Multiple Files'
                            'Line' = ''
                            'Type' = 'Entity Framework'
                            'Category' = 'ORM'
                            'Pattern' = 'EF patterns'
                            'Code Context' = "Found $($script:Results.EfFindings) Entity Framework references"
                            'Database Objects' = 'Entity Classes, DbSets'
                            'Object Types' = 'Table/Entity'
                            'Schema References' = 'Default/Configured schemas'
                            'SQL Object' = 'Database Context'
                            'Description' = 'Entity Framework usage detected'
                            'Confidence' = 'High'
                        }
                    }
                    
                    if ($script:Results.AdoFindings -gt 0) {
                        $sqlDependencies += [PSCustomObject]@{
                            'File' = 'Multiple Files'
                            'Line' = ''
                            'Type' = 'ADO.NET'
                            'Category' = 'Data Access'
                            'Pattern' = 'ADO.NET patterns'
                            'Code Context' = "Found $($script:Results.AdoFindings) ADO.NET references"
                            'Database Objects' = 'SQL Commands, DataReaders'
                            'Object Types' = 'Connection, Command'
                            'Schema References' = 'Runtime determined'
                            'SQL Object' = 'Database Connection'
                            'Description' = 'ADO.NET usage detected'
                            'Confidence' = 'High'
                        }
                    }
                }
                
                if ($sqlDependencies.Count -gt 0) {
                    $sqlDependencies | Export-Excel -Path $excelFile -WorksheetName "SQL Dependencies" -AutoSize -BoldTopRow -TableStyle Medium12 -FreezeTopRow
                    Write-Host "  Added $($sqlDependencies.Count) SQL dependency entries" -ForegroundColor Green
                } else {
                    Write-Host "  No SQL dependencies found to export" -ForegroundColor Yellow
                }
            } else {
                Write-Warning "  JSON file not found, skipping SQL Dependencies worksheet"
            }
        } catch {
            Write-Warning "  Could not process SQL dependencies: $($_.Exception.Message)"
            Write-Host "  Error details: $($_.Exception)" -ForegroundColor Red
        }
        
        # Database Objects Analysis worksheet
        try {
            if ($sqlDependencies.Count -gt 0) {
                Write-Host "  Creating database objects analysis..." -ForegroundColor Gray
                
                # Extract and analyze all database objects
                $dbObjectsAnalysis = @()
                foreach ($dependency in $sqlDependencies) {
                    if ($dependency.'Database Objects' -and $dependency.'Database Objects'.Trim() -ne '') {
                        $objects = $dependency.'Database Objects' -split ', '
                        $types = if ($dependency.'Object Types') { $dependency.'Object Types' -split ', ' } else { @('Unknown') }
                        $schemas = if ($dependency.'Schema References') { $dependency.'Schema References' -split ', ' } else { @('') }
                        
                        for ($i = 0; $i -lt $objects.Count; $i++) {
                            if ($objects[$i].Trim() -ne '') {
                                $dbObjectsAnalysis += [PSCustomObject]@{
                                    'Database Object' = $objects[$i].Trim()
                                    'Object Type' = if ($i -lt $types.Count) { $types[$i].Trim() } else { if ($types.Count -gt 0) { $types[0].Trim() } else { 'Unknown' } }
                                    'Schema' = if ($i -lt $schemas.Count) { $schemas[$i].Trim() } else { if ($schemas.Count -gt 0 -and $schemas[0].Trim() -ne '') { $schemas[0].Trim() } else { 'dbo' } }
                                    'SQL Type' = $dependency.Type
                                    'Category' = $dependency.Category
                                    'Source File' = $dependency.File
                                    'Line Number' = $dependency.Line
                                    'Context Preview' = if ($dependency.'Code Context'.Length -gt 150) { $dependency.'Code Context'.Substring(0, 147) + "..." } else { $dependency.'Code Context' }
                                }
                            }
                        }
                    }
                }
                
                # Group and summarize database objects
                $dbObjectsSummary = $dbObjectsAnalysis | 
                    Group-Object 'Database Object' | 
                    ForEach-Object {
                        [PSCustomObject]@{
                            'Database Object' = $_.Name
                            'Object Type' = ($_.Group.'Object Type' | Select-Object -First 1)
                            'Schema' = ($_.Group.Schema | Select-Object -First 1)
                            'Usage Count' = $_.Count
                            'SQL Types Used' = (($_.Group.'SQL Type' | Select-Object -Unique) -join ', ')
                            'Categories' = (($_.Group.Category | Select-Object -Unique) -join ', ')
                            'Files Count' = ($_.Group.'Source File' | Select-Object -Unique).Count
                            'Sample Files' = (($_.Group.'Source File' | Select-Object -Unique -First 3) -join '; ')
                        }
                    } | Sort-Object 'Usage Count' -Descending
                
                if ($dbObjectsSummary.Count -gt 0) {
                    $dbObjectsSummary | Export-Excel -Path $excelFile -WorksheetName "Database Objects" -AutoSize -BoldTopRow -TableStyle Medium10
                    Write-Host "  Added $($dbObjectsSummary.Count) unique database objects" -ForegroundColor Green
                }
            }
        } catch {
            Write-Warning "  Could not create database objects analysis: $($_.Exception.Message)"
        }

        # SQL Summary by Type worksheet
        try {
            if ($sqlDependencies.Count -gt 0) {
                Write-Host "  Creating SQL summary by type..." -ForegroundColor Gray
                
                # Group SQL dependencies by type and category
                $sqlSummary = $sqlDependencies | 
                    Group-Object Type | 
                    ForEach-Object {
                        $categoryBreakdown = $_.Group | Group-Object Category | ForEach-Object { "$($_.Name) ($($_.Count))" } | Join-String ", "
                        $uniqueObjects = ($_.Group.'Database Objects' | Where-Object { $_ } | ForEach-Object { $_ -split ', ' } | Select-Object -Unique | Where-Object { $_.Trim() -ne '' }) -join ', '
                        $uniqueTypes = ($_.Group.'Object Types' | Where-Object { $_ } | ForEach-Object { $_ -split ', ' } | Select-Object -Unique | Where-Object { $_.Trim() -ne '' }) -join ', '
                        $uniqueSchemas = ($_.Group.'Schema References' | Where-Object { $_ } | ForEach-Object { $_ -split ', ' } | Select-Object -Unique | Where-Object { $_.Trim() -ne '' }) -join ', '
                        
                        [PSCustomObject]@{
                            'SQL Type' = $_.Name
                            'Total Count' = $_.Count
                            'Percentage' = [math]::Round(($_.Count / $sqlDependencies.Count) * 100, 2)
                            'Categories' = $categoryBreakdown
                            'Files Affected' = ($_.Group.File | Select-Object -Unique).Count
                            'Database Objects' = if ($uniqueObjects.Length -gt 100) { $uniqueObjects.Substring(0, 97) + "..." } else { $uniqueObjects }
                            'Object Types' = $uniqueTypes
                            'Schema References' = $uniqueSchemas
                            'Sample Context' = if (($_.Group[0].'Code Context').Length -gt 80) { ($_.Group[0].'Code Context').Substring(0, 77) + "..." } else { $_.Group[0].'Code Context' }
                        }
                    } | Sort-Object 'Total Count' -Descending
                
                $sqlSummary | Export-Excel -Path $excelFile -WorksheetName "SQL Summary" -AutoSize -BoldTopRow -TableStyle Medium14
                Write-Host "  Added SQL summary with $($sqlSummary.Count) types" -ForegroundColor Green
            }
        } catch {
            Write-Warning "  Could not create SQL summary: $($_.Exception.Message)"
        }
        
        Write-Success "Comprehensive Excel report generated: $(Split-Path $excelFile -Leaf)"
        Write-Host "  Worksheets: Summary, Files, FileTypes, Categories, Configuration, SQL Dependencies, Database Objects, SQL Summary" -ForegroundColor Gray
        
        if ($OpenResults) {
            Start-Process $excelFile
        }
        
    } catch {
        Write-Warning "Could not generate Excel report: $($_.Exception.Message)"
        Write-Host "Error details: $($_.Exception)" -ForegroundColor Red
    }
}

function Show-Summary {
    $executionTime = (Get-Date) - $script:Results.StartTime
    
    Write-Host "`n================================================================" -ForegroundColor Cyan
    Write-Host "           [SUCCESS] Analysis Complete!" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Cyan
    
    Write-Host "`n[STATS] Summary Statistics:" -ForegroundColor Yellow
    Write-Host "  Run ID: $($script:Config.RunId)" -ForegroundColor Magenta
    Write-Host "  Total Files Scanned: $($script:Results.TotalScanned)" -ForegroundColor Yellow
    Write-Host "  Files Analyzed: $($script:Results.CopiedFiles.Count)" -ForegroundColor Green
    Write-Host "  Files Skipped: $($script:Results.SkippedFiles.Count)" -ForegroundColor Gray
    Write-Host "  Total Findings: $($script:Results.TotalFindings)" -ForegroundColor Cyan
    Write-Host "  Entity Framework: $($script:Results.EfFindings)" -ForegroundColor Cyan
    Write-Host "  SQL Statements: $($script:Results.SqlFindings)" -ForegroundColor Cyan
    Write-Host "  ADO.NET: $($script:Results.AdoFindings)" -ForegroundColor Cyan
    Write-Host "  Execution Time: $($executionTime.ToString("hh\:mm\:ss"))" -ForegroundColor Gray
    
    Write-Host "`n[OUTPUT] Output Location:" -ForegroundColor Yellow
    Write-Host "  $($script:Results.AnalysisDir)" -ForegroundColor Gray
    
    Write-Host "`n[FILES] Key Files:" -ForegroundColor Yellow
    Write-Host "  Report: $(Split-Path $script:Results.ReportFile -Leaf)" -ForegroundColor Green
    Write-Host "  SQL Output: mbox-complete-analysis.sql" -ForegroundColor Green
    Write-Host "  JSON Data: mbox-complete-analysis.json" -ForegroundColor Green
    
    Write-Host "`n[COMMANDS] PowerShell Commands:" -ForegroundColor Yellow
    Write-Host "  Get-ChildItem '$($script:Results.AnalysisDir)'" -ForegroundColor Blue
    Write-Host "  Invoke-Item '$($script:Results.AnalysisDir)'" -ForegroundColor Blue
    
    Write-Host "`n[+] Analysis completed successfully!" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Cyan
}

function Remove-TemporaryFiles {
    Write-Phase "Cleaning up temporary files..." "[*]"
    
    if ($script:InputDir -and (Test-Path $script:InputDir)) {
        Remove-Item -Path $script:InputDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Success "Cleaned up input directory"
    }
    
    Pop-Location
}

#endregion

#region Main Execution

function Invoke-MBoxAnalysis {
    [CmdletBinding()]
    param()
    
    try {
        # Banner
        Write-Banner "MBox Platform SQL Dependency Analysis" "PowerShell Edition"
        
        # Validation
        if (-not $SkipValidation) {
            Test-Prerequisites
        }
        
        # Setup
        $dirs = Initialize-AnalysisEnvironment
        
        # File selection
        $fileStats = Copy-AnalysisFiles
        $script:Results.TotalScanned = $fileStats.TotalScanned
        
        if ($fileStats.CopiedCount -eq 0) {
            throw "No files found to analyze"
        }
        
        # Analysis
        $analysisSuccess = Invoke-Analysis
        
        if (-not $analysisSuccess) {
            throw "Analysis execution failed"
        }
        
        # Reporting
        New-AnalysisReport
        New-ExcelReport
        
        # Summary
        Show-Summary
        
        # Open results if requested
        if ($OpenResults) {
            Write-Info "Opening results folder..."
            Invoke-Item $script:Results.AnalysisDir
        }
        
        Write-Host "`n[INFO] Run this script again anytime to get fresh analysis results!" -ForegroundColor Green
        Write-Host "PowerShell Command: .\Run-MBoxAnalysisComplete.ps1" -ForegroundColor Blue
        
    } catch {
        Write-Error "Analysis failed: $($_.Exception.Message)"
        
        if ($_.Exception.InnerException) {
            Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        }
        
        Write-Host "`nFor troubleshooting, check:" -ForegroundColor Yellow
        Write-Host "  - MBox Platform path: $($script:MBoxPath)" -ForegroundColor Gray
        Write-Host "  - SQLDepends tools: $($script:Config.SqlDependsPath)" -ForegroundColor Gray
        Write-Host "  - Python3 availability: python3 --version" -ForegroundColor Gray
        
        exit 1
    } finally {
        # Cleanup
        Remove-TemporaryFiles
    }
}

#endregion

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-MBoxAnalysis
}