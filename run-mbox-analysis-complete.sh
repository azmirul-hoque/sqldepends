#!/bin/bash

# Complete MBox Platform SQL Analysis Script
# Runs comprehensive analysis of MBox Platform from any location
# Automatically handles setup, execution, and reporting

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MBOX_PATH="/mnt/d/dev2/mbox-platform"
SQLDEPENDS_PATH="/mnt/d/dev2/sqldepends"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RUN_ID="mbox-analysis-${TIMESTAMP}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}           MBox Platform SQL Dependency Analysis${NC}"
echo -e "${BLUE}================================================================${NC}"
echo -e "${PURPLE}Run ID: ${RUN_ID}${NC}"
echo -e "${PURPLE}Timestamp: $(date)${NC}"
echo -e "${BLUE}================================================================${NC}"

# Validation function
validate_environment() {
    echo -e "${YELLOW}🔍 Validating environment...${NC}"
    
    local errors=0
    
    # Check if MBox Platform exists
    if [[ ! -d "$MBOX_PATH" ]]; then
        echo -e "${RED}✗ MBox Platform not found at: $MBOX_PATH${NC}"
        errors=$((errors + 1))
    else
        echo -e "${GREEN}✓ MBox Platform found${NC}"
    fi
    
    # Check if sqldepends tools exist
    if [[ ! -d "$SQLDEPENDS_PATH" ]]; then
        echo -e "${RED}✗ SQLDepends tools not found at: $SQLDEPENDS_PATH${NC}"
        errors=$((errors + 1))
    else
        echo -e "${GREEN}✓ SQLDepends tools found${NC}"
    fi
    
    # Check for required scripts
    local required_scripts=(
        "quick-sql-analyzer.py"
        "config-mbox-analysis.json"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$SQLDEPENDS_PATH/$script" ]]; then
            echo -e "${RED}✗ Required script missing: $script${NC}"
            errors=$((errors + 1))
        else
            echo -e "${GREEN}✓ Found: $script${NC}"
        fi
    done
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}✗ Python3 not found${NC}"
        errors=$((errors + 1))
    else
        echo -e "${GREEN}✓ Python3 available${NC}"
    fi
    
    if [[ $errors -gt 0 ]]; then
        echo -e "${RED}❌ Environment validation failed with $errors errors${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Environment validation passed${NC}"
    echo ""
}

# Setup function
setup_analysis() {
    echo -e "${YELLOW}🔧 Setting up analysis environment...${NC}"
    
    # Navigate to sqldepends directory
    cd "$SQLDEPENDS_PATH"
    
    # Create analysis directories
    local analysis_dir="analysis-output/mbox-platform/${RUN_ID}"
    local input_dir="analysis-input/mbox-${RUN_ID}"
    
    mkdir -p "$analysis_dir"
    mkdir -p "$input_dir"
    mkdir -p "logs"
    
    echo -e "${GREEN}✓ Analysis directories created${NC}"
    echo "  Input: $input_dir"
    echo "  Output: $analysis_dir"
    echo ""
    
    # Export paths for use in other functions
    export ANALYSIS_DIR="$analysis_dir"
    export INPUT_DIR="$input_dir"
}

# File selection function
select_analysis_files() {
    echo -e "${YELLOW}📁 Selecting files for comprehensive analysis...${NC}"
    
    # Define comprehensive file sets
    local file_sets=(
        # Core Infrastructure
        "src/MBox.Platform.Infrastructure/ApplicationContext.cs"
        "src/MBox.Platform.Infrastructure/ApplicationContext.Entities.cs"
        "src/MBox.Platform.Infrastructure/ApplicationContext.Procedures.cs"
        "src/MBox.Platform.Infrastructure/ApplicationContext.Views.cs"
        "src/MBox.Platform.Infrastructure/ApplicationContext.Functions.cs"
        
        # Services
        "src/MBox.Platform.Services/EmailService.cs"
        "src/MBox.Platform.Services/AlertService.cs"
        "src/MBox.Platform.Services/UnitOfWorkService.cs"
        "src/MBox.Platform.Services/EventService.cs"
        "src/MBox.Platform.Services/MachineService.cs"
        
        # Event Processing
        "src/MBox.Platform.Events/ProcessedEvents/EvaluateMonitorAlertSources.cs"
        "src/MBox.Platform.Events/Machines/EvaluateAlertSources.cs"
        "src/MBox.Platform.Events/ProcessedEvents/HandleBarcodeActivities.cs"
        "src/MBox.Platform.Events/ProcessedEvents/GenerateAvailableEventWhenWorkingTimeChanges.cs"
        
        # API Layer
        "src/MBox.Platform.Host.Api/Program.cs"
        "src/MBox.Platform.Host.Api/Startup.cs"
        
        # Functions (Data Operations)
        "src/MBox.Platform.Host.Functions/Alerts/UpdateMonitorAlerts.cs"
        "src/MBox.Platform.Host.Functions/Events/ComputeCycleTimeEvents.cs"
        "src/MBox.Platform.Host.Functions/Events/ComputeScheduleEvents.cs"
        "src/MBox.Platform.Host.Functions/Events/ComputeWorkingTimeEvents.cs"
        "src/MBox.Platform.Host.Functions/InsertInto/InsertIntoDailyProduction.cs"
        "src/MBox.Platform.Host.Functions/InsertInto/InsertIntoMetrics.cs"
        "src/MBox.Platform.Host.Functions/InsertInto/InsertIntoTAcceptedDaily.cs"
        "src/MBox.Platform.Host.Functions/InsertInto/InsertIntoTMachineStops.cs"
    )
    
    # Copy files
    local copied_files=()
    local missing_files=()
    
    for file in "${file_sets[@]}"; do
        local full_path="$MBOX_PATH/$file"
        
        if [[ -f "$full_path" ]]; then
            # Create directory structure
            local target_dir="$INPUT_DIR/$(dirname "$file")"
            mkdir -p "$target_dir"
            
            # Copy file
            cp "$full_path" "$INPUT_DIR/$file"
            copied_files+=("$file")
            echo -e "  ${GREEN}✓${NC} Copied: $(basename "$file")"
        else
            missing_files+=("$file")
            echo -e "  ${RED}✗${NC} Missing: $(basename "$file")"
        fi
    done
    
    echo ""
    echo -e "${GREEN}📊 File Selection Summary:${NC}"
    echo -e "  Copied: ${GREEN}${#copied_files[@]}${NC} files"
    echo -e "  Missing: ${RED}${#missing_files[@]}${NC} files"
    echo ""
    
    # Export for reporting
    export COPIED_FILES_COUNT=${#copied_files[@]}
    export MISSING_FILES_COUNT=${#missing_files[@]}
    
    # Save file lists for reporting
    printf "%s\n" "${copied_files[@]}" > "$ANALYSIS_DIR/copied-files.txt"
    printf "%s\n" "${missing_files[@]}" > "$ANALYSIS_DIR/missing-files.txt"
}

# Analysis execution function
run_analysis() {
    echo -e "${YELLOW}🔬 Running SQL dependency analysis...${NC}"
    
    local output_file="$ANALYSIS_DIR/mbox-complete-analysis.sql"
    local json_output="$ANALYSIS_DIR/mbox-complete-analysis.json"
    local log_file="logs/mbox-complete-${TIMESTAMP}.log"
    
    echo "Analysis files:"
    echo "  SQL Output: $output_file"
    echo "  JSON Output: $json_output"
    echo "  Log File: $log_file"
    echo ""
    
    # Run SQL analysis
    echo -e "${BLUE}Running SQL pattern analysis...${NC}"
    python3 quick-sql-analyzer.py \
        --directory "$INPUT_DIR" \
        --output "$output_file" \
        --format sql 2>&1 | tee "$log_file"
    
    local sql_exit_code=${PIPESTATUS[0]}
    
    # Run JSON analysis for detailed data
    echo -e "${BLUE}Running JSON analysis for detailed data...${NC}"
    python3 quick-sql-analyzer.py \
        --directory "$INPUT_DIR" \
        --output "$json_output" \
        --format json 2>&1 | tee -a "$log_file"
    
    local json_exit_code=${PIPESTATUS[0]}
    
    if [[ $sql_exit_code -eq 0 && $json_exit_code -eq 0 ]]; then
        echo -e "${GREEN}✅ Analysis completed successfully${NC}"
        
        # Extract summary statistics
        if [[ -f "$json_output" ]]; then
            local total_findings=$(python3 -c "import json; data=json.load(open('$json_output')); print(data['total_findings'])" 2>/dev/null || echo "0")
            local sql_findings=$(python3 -c "import json; data=json.load(open('$json_output')); print(data['summary']['sql_statements'])" 2>/dev/null || echo "0")
            local ef_findings=$(python3 -c "import json; data=json.load(open('$json_output')); print(data['summary']['entity_framework'])" 2>/dev/null || echo "0")
            local ado_findings=$(python3 -c "import json; data=json.load(open('$json_output')); print(data['summary']['ado_net'])" 2>/dev/null || echo "0")
            
            echo ""
            echo -e "${GREEN}📈 Analysis Results:${NC}"
            echo -e "  Total findings: ${BLUE}$total_findings${NC}"
            echo -e "  SQL statements: ${BLUE}$sql_findings${NC}"
            echo -e "  Entity Framework: ${BLUE}$ef_findings${NC}"
            echo -e "  ADO.NET: ${BLUE}$ado_findings${NC}"
            
            # Export for reporting
            export TOTAL_FINDINGS=$total_findings
            export SQL_FINDINGS=$sql_findings
            export EF_FINDINGS=$ef_findings
            export ADO_FINDINGS=$ado_findings
        fi
        
        return 0
    else
        echo -e "${RED}❌ Analysis failed${NC}"
        echo -e "  SQL analysis exit code: $sql_exit_code"
        echo -e "  JSON analysis exit code: $json_exit_code"
        return 1
    fi
}

# Report generation function
generate_report() {
    echo -e "${YELLOW}📋 Generating comprehensive report...${NC}"
    
    local report_file="$ANALYSIS_DIR/MBOX-ANALYSIS-REPORT-${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# MBox Platform SQL Analysis Report

**Generated:** $(date)  
**Run ID:** ${RUN_ID}  
**Analysis Tool:** sqldepends v2.0.0  
**Execution Mode:** Complete automated analysis  

## Executive Summary

This automated analysis examined ${COPIED_FILES_COUNT:-0} files from the MBox Platform project to identify SQL dependencies, Entity Framework usage, and ADO.NET patterns.

## Analysis Statistics

- **Files Analyzed:** ${COPIED_FILES_COUNT:-0}
- **Files Missing:** ${MISSING_FILES_COUNT:-0}
- **Total Findings:** ${TOTAL_FINDINGS:-0}
- **SQL Statements:** ${SQL_FINDINGS:-0}
- **Entity Framework References:** ${EF_FINDINGS:-0}
- **ADO.NET References:** ${ADO_FINDINGS:-0}

## Files Analyzed

### Successfully Processed
EOF

    # Add file lists
    if [[ -f "$ANALYSIS_DIR/copied-files.txt" ]]; then
        while read -r file; do
            echo "- $file" >> "$report_file"
        done < "$ANALYSIS_DIR/copied-files.txt"
    fi
    
    if [[ -f "$ANALYSIS_DIR/missing-files.txt" && -s "$ANALYSIS_DIR/missing-files.txt" ]]; then
        echo "" >> "$report_file"
        echo "### Missing Files" >> "$report_file"
        while read -r file; do
            echo "- $file" >> "$report_file"
        done < "$ANALYSIS_DIR/missing-files.txt"
    fi
    
    cat >> "$report_file" << EOF

## Key Findings

$(if [[ ${EF_FINDINGS:-0} -gt 0 ]]; then echo "✅ **Entity Framework Usage Detected** - $EF_FINDINGS references found"; fi)
$(if [[ ${SQL_FINDINGS:-0} -gt 0 ]]; then echo "✅ **Direct SQL Usage Detected** - $SQL_FINDINGS statements found"; fi)
$(if [[ ${ADO_FINDINGS:-0} -gt 0 ]]; then echo "✅ **ADO.NET Usage Detected** - $ADO_FINDINGS references found"; fi)

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
- **Execution Log:** ../../../logs/mbox-complete-${TIMESTAMP}.log
- **This Report:** $(basename "$report_file")

## Analysis Methodology

### Safety Measures
✅ Read-only analysis - No modifications to source code  
✅ Isolated execution - All analysis in separate directory  
✅ Automated file selection - Consistent target files  
✅ Comprehensive logging - Full execution trace  

### Tool Configuration
- **Pattern Detection:** SQL statements, Entity Framework, ADO.NET
- **File Types:** C# source files (.cs)
- **Exclusions:** Build artifacts, temporary files, auto-generated code
- **Analysis Engine:** quick-sql-analyzer.py with enhanced pattern recognition

---

**Analysis completed successfully at $(date)**  
*Report generated by automated MBox Platform analysis script*
EOF

    echo -e "${GREEN}✅ Report generated: $(basename "$report_file")${NC}"
    echo ""
    
    # Export report path
    export REPORT_FILE="$report_file"
}

# Summary function
show_summary() {
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${GREEN}           🎉 Analysis Complete! 🎉${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo ""
    echo -e "${YELLOW}📊 Summary Statistics:${NC}"
    echo -e "  Run ID: ${PURPLE}${RUN_ID}${NC}"
    echo -e "  Files Analyzed: ${GREEN}${COPIED_FILES_COUNT:-0}${NC}"
    echo -e "  Total Findings: ${BLUE}${TOTAL_FINDINGS:-0}${NC}"
    echo -e "  Entity Framework: ${BLUE}${EF_FINDINGS:-0}${NC}"
    echo -e "  SQL Statements: ${BLUE}${SQL_FINDINGS:-0}${NC}"
    echo -e "  ADO.NET: ${BLUE}${ADO_FINDINGS:-0}${NC}"
    echo ""
    echo -e "${YELLOW}📁 Output Location:${NC}"
    echo -e "  ${ANALYSIS_DIR}"
    echo ""
    echo -e "${YELLOW}📋 Key Files:${NC}"
    echo -e "  Report: ${GREEN}$(basename "${REPORT_FILE}")${NC}"
    echo -e "  SQL Output: ${GREEN}mbox-complete-analysis.sql${NC}"
    echo -e "  JSON Data: ${GREEN}mbox-complete-analysis.json${NC}"
    echo ""
    echo -e "${YELLOW}🔍 Quick View Command:${NC}"
    echo -e "  ${BLUE}ls -la \"${ANALYSIS_DIR}\"${NC}"
    echo ""
    echo -e "${GREEN}✅ Analysis completed successfully!${NC}"
    echo -e "${BLUE}================================================================${NC}"
}

# Cleanup function
cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
    
    # Remove input files (they're copied, not moved)
    if [[ -n "$INPUT_DIR" && -d "$INPUT_DIR" ]]; then
        rm -rf "$INPUT_DIR"
        echo -e "${GREEN}✓ Cleaned up input directory${NC}"
    fi
}

# Error handling
handle_error() {
    echo -e "${RED}❌ Analysis failed with error on line $1${NC}"
    echo -e "${YELLOW}Check the log files for detailed error information${NC}"
    cleanup
    exit 1
}

# Set up error handling
trap 'handle_error $LINENO' ERR

# Main execution
main() {
    validate_environment
    setup_analysis
    select_analysis_files
    
    if [[ ${COPIED_FILES_COUNT:-0} -eq 0 ]]; then
        echo -e "${RED}❌ No files found to analyze${NC}"
        exit 1
    fi
    
    run_analysis
    generate_report
    show_summary
    cleanup
    
    echo -e "${GREEN}🎯 Run this script again anytime to get fresh analysis results!${NC}"
}

# Execute main function
main "$@"