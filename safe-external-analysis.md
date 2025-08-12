# Safe External Project Analysis Guide

## How to Analyze MBox Platform from SQLDepends Project

Since we're restricted to working within the sqldepends directory for security, here's how to safely analyze the mbox-platform project:

### Option 1: Copy Specific Files for Analysis

```bash
# Create a safe copy of specific files for analysis
mkdir -p ./analysis-input/mbox-sample

# Copy a few key files to analyze (manual selection)
cp /mnt/d/dev2/mbox-platform/src/MBox.Platform.Infrastructure/ApplicationContext.cs ./analysis-input/mbox-sample/
cp /mnt/d/dev2/mbox-platform/src/MBox.Platform.Services/EmailService.cs ./analysis-input/mbox-sample/
cp /mnt/d/dev2/mbox-platform/appsettings.json ./analysis-input/mbox-sample/

# Run analysis on the copied files
python3 sql_analyzer.py --directory ./analysis-input/mbox-sample --output-file ./analysis-output/mbox-sample-analysis.sql --dry-run
```

### Option 2: Manual File Review

Review key files that are likely to contain SQL dependencies:

1. **Infrastructure Files:**
   - `src/MBox.Platform.Infrastructure/ApplicationContext.cs`
   - `src/MBox.Platform.Infrastructure/ApplicationContext.*.cs`

2. **Service Files:**
   - `src/MBox.Platform.Services/*.cs`
   - `src/MBox.Platform.Events/*.cs`

3. **Database Schema Files:**
   - `src/MBox.Platform.Infrastructure.SqlServer/*.sql`

4. **Configuration Files:**
   - `appsettings.json`
   - Any `*.config` files

### Option 3: Generate Analysis Commands

Create commands that can be run from the mbox-platform directory:

```bash
# Count file types
find . -name "*.cs" | wc -l
find . -name "*.sql" | wc -l

# Search for SQL patterns
grep -r "SqlCommand" src/ --include="*.cs" | head -10
grep -r "DbContext" src/ --include="*.cs" | head -10
grep -r "FromSqlRaw" src/ --include="*.cs" | head -10
grep -r "ConnectionString" . --include="*.json" --include="*.config"

# Find Entity Framework usage
grep -r "DbSet<" src/ --include="*.cs"
grep -r "Entity" src/ --include="*.cs" | grep "Framework"
```

### Option 4: Use the Configured Tools from MBox Directory

The user can run these commands from the mbox-platform directory:

```bash
# Navigate to mbox-platform
cd /mnt/d/dev2/mbox-platform

# Run sqldepends analysis from there
/mnt/d/dev2/sqldepends/sql_analyzer.py \
    --directory . \
    --config-file /mnt/d/dev2/sqldepends/config-mbox-analysis.json \
    --output-file /mnt/d/dev2/sqldepends/analysis-output/mbox-platform/full-analysis.sql \
    --dry-run \
    --parallel

# Or use the shell script
/mnt/d/dev2/sqldepends/run-mbox-analysis.sh
```

## What We Can Provide

From the sqldepends directory, I can provide:

✅ **Analysis Configuration** - Optimized config for .NET projects
✅ **Analysis Scripts** - Ready-to-run scripts for safe analysis  
✅ **Documentation** - Complete guide for running analysis
✅ **Result Processing** - Tools to process and interpret results
✅ **Report Templates** - Structured reporting formats

## Recommended Approach

1. **Use the prepared scripts:** The `run-mbox-analysis.sh` script is designed to run safely
2. **Copy sample files:** Manually copy a few representative files for testing
3. **Run from mbox directory:** Execute the analysis tools from the target project directory
4. **Review results:** Use the isolated output directory for all results

## Safety Guarantees

- ✅ Read-only access to source files
- ✅ No modifications to source project
- ✅ Isolated output directory
- ✅ Dry-run mode prevents database connections
- ✅ No side effects on source project

The analysis tools are ready to use - they just need to be executed from the appropriate directory or with copied sample files.