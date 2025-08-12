#!/bin/bash

# Safe MBox Platform Analysis Script
# Runs SQL dependency analysis on the mbox-platform project without affecting it

echo "Starting Safe MBox Platform Analysis..."
echo "======================================="

# Configuration
MBOX_PATH="/mnt/d/dev2/mbox-platform"
OUTPUT_DIR="./analysis-output/mbox-platform"
CONFIG_FILE="./config-mbox-analysis.json"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Validate source directory exists
if [ ! -d "$MBOX_PATH" ]; then
    echo "ERROR: MBox Platform directory not found at $MBOX_PATH"
    exit 1
fi

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"
mkdir -p "./logs"

echo "Source Directory: $MBOX_PATH"
echo "Output Directory: $OUTPUT_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""

# Run Python analysis (read-only mode)
echo "Running Python analysis..."
python3 sql_analyzer.py \
    --config-file "$CONFIG_FILE" \
    --directory "$MBOX_PATH" \
    --output-file "$OUTPUT_DIR/mbox-platform-analysis-${TIMESTAMP}.sql" \
    --export-format sql \
    --log-level INFO \
    --log-file "./logs/mbox-analysis-${TIMESTAMP}.log" \
    --parallel \
    --dry-run

PYTHON_EXIT_CODE=$?

if [ $PYTHON_EXIT_CODE -eq 0 ]; then
    echo "✓ Python analysis completed successfully"
else
    echo "✗ Python analysis failed with exit code $PYTHON_EXIT_CODE"
fi

echo ""

# Run PowerShell analysis (if available)
if command -v pwsh &> /dev/null; then
    echo "Running PowerShell analysis..."
    pwsh -c "
        ./Analyze-SqlCode.ps1 \
            -Directory '$MBOX_PATH' \
            -OutputFile '$OUTPUT_DIR/mbox-platform-ps-analysis-${TIMESTAMP}.sql' \
            -ExportFormat 'SQL' \
            -DryRun \
            -LogLevel 'Info' \
            -Verbose
    "
    
    PS_EXIT_CODE=$?
    
    if [ $PS_EXIT_CODE -eq 0 ]; then
        echo "✓ PowerShell analysis completed successfully"
    else
        echo "✗ PowerShell analysis failed with exit code $PS_EXIT_CODE"
    fi
else
    echo "PowerShell not available, skipping PowerShell analysis"
fi

echo ""

# Generate summary report
echo "Generating analysis summary..."

cat > "$OUTPUT_DIR/analysis-summary-${TIMESTAMP}.md" << EOF
# MBox Platform SQL Analysis Summary

**Analysis Date:** $(date)
**Source Directory:** $MBOX_PATH
**Output Directory:** $OUTPUT_DIR
**Configuration:** $CONFIG_FILE

## Analysis Scope

This analysis was performed in **read-only mode** on the MBox Platform project to identify:

- Entity Framework usage patterns
- SQL Server database object references
- ADO.NET connection and command patterns
- Configuration-based SQL statements
- Potential SQL injection risks

## Files Analyzed

### Priority Areas
- \`src/MBox.Platform.Infrastructure/\` - Core data infrastructure
- \`src/MBox.Platform.Services/\` - Business logic services
- \`src/MBox.Platform.Events/\` - Event handling logic
- \`src/MBox.Platform.Host.Api/\` - API controllers and endpoints
- \`src/MBox.Platform.Host.Functions/\` - Azure Functions

### File Types Included
- C# source files (*.cs)
- SQL scripts (*.sql)
- Configuration files (*.json)
- Razor views (*.cshtml)

### Excluded Directories
- bin/, obj/ - Build artifacts
- packages/, node_modules/ - Package dependencies
- .git/, .vs/ - Version control and IDE files
- Connected Services/ - Auto-generated service references

## Safety Measures

✓ **Read-only analysis** - No files modified in source project
✓ **Isolated output** - All results written to separate directory
✓ **Dry-run mode** - No database connections attempted
✓ **No side effects** - Source project completely unaffected

## Output Files

- \`mbox-platform-analysis-${TIMESTAMP}.sql\` - Main SQL analysis results
- \`mbox-platform-ps-analysis-${TIMESTAMP}.sql\` - PowerShell analysis (if available)
- \`analysis-summary-${TIMESTAMP}.md\` - This summary report
- \`../logs/mbox-analysis-${TIMESTAMP}.log\` - Detailed execution log

## Next Steps

1. Review the generated SQL file for database dependencies
2. Analyze Entity Framework usage patterns
3. Identify potential performance or security issues
4. Generate reports for architecture review

**Note:** This analysis was performed from the sqldepends project directory without affecting the source MBox Platform project in any way.
EOF

echo "✓ Analysis summary generated"
echo ""

# Display results
echo "Analysis Results:"
echo "=================="
echo "Output files created in: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"
echo ""

if [ -f "./logs/mbox-analysis-${TIMESTAMP}.log" ]; then
    echo "Log file size: $(du -h ./logs/mbox-analysis-${TIMESTAMP}.log | cut -f1)"
    echo ""
    echo "Last 10 lines of log:"
    tail -10 "./logs/mbox-analysis-${TIMESTAMP}.log"
fi

echo ""
echo "Safe analysis completed! No changes made to $MBOX_PATH"
echo "All results isolated in: $OUTPUT_DIR"