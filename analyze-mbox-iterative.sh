#!/bin/bash

# Iterative MBox Platform Analysis Script
# Runs targeted analysis on specific files, evaluates results, and provides improvement feedback

set -e  # Exit on any error

# Configuration
MBOX_PATH="/mnt/d/dev2/mbox-platform"
ANALYSIS_INPUT="./analysis-input/mbox-sample"
ANALYSIS_OUTPUT="./analysis-output/mbox-platform"
CONFIG_FILE="./config-mbox-analysis.json"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ITERATION=${1:-1}  # Allow iteration number as parameter

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}MBox Platform Iterative Analysis${NC}"
echo -e "${BLUE}Iteration: $ITERATION${NC}"
echo -e "${BLUE}Timestamp: $TIMESTAMP${NC}"
echo -e "${BLUE}================================${NC}"

# Create directories
mkdir -p "$ANALYSIS_INPUT" "$ANALYSIS_OUTPUT" "./logs"

# Function to check if a file should be ignored based on gitignore patterns
is_gitignored() {
    local file="$1"
    local gitignore_patterns=(
        "bin/" "obj/" "packages/" "node_modules/" ".git/" ".vs/" "__pycache__/"
        "*.log" "*.tmp" "*.bak" "*.user" "*.suo" "*.cache"
        "Connected Services/" "wwwroot/lib/" "TestResults/"
    )
    
    for pattern in "${gitignore_patterns[@]}"; do
        if [[ "$file" == *"$pattern"* ]]; then
            return 0  # File should be ignored
        fi
    done
    return 1  # File should not be ignored
}

# Function to copy specific files for analysis
copy_target_files() {
    echo -e "${YELLOW}Phase 1: Selecting target files for analysis...${NC}"
    
    # Clear previous iteration
    rm -rf "$ANALYSIS_INPUT"/*
    
    # Define file sets by iteration
    case $ITERATION in
        1)
            echo "Iteration 1: Core Infrastructure Files"
            TARGET_FILES=(
                "src/MBox.Platform.Infrastructure/ApplicationContext.cs"
                "src/MBox.Platform.Services/EmailService.cs"
                "src/MBox.Platform.Services/AlertService.cs"
                "appsettings.json"
            )
            ;;
        2)
            echo "Iteration 2: Event Processing Files"
            TARGET_FILES=(
                "src/MBox.Platform.Events/ProcessedEvents/EvaluateMonitorAlertSources.cs"
                "src/MBox.Platform.Events/Machines/EvaluateAlertSources.cs"
                "src/MBox.Platform.Host.Functions/Alerts/UpdateMonitorAlerts.cs"
                "src/MBox.Platform.Infrastructure/ApplicationContext.Entities.cs"
            )
            ;;
        3)
            echo "Iteration 3: API and Database Files"
            TARGET_FILES=(
                "src/MBox.Platform.Host.Api/Program.cs"
                "src/MBox.Platform.Host.Api/Startup.cs"
                "src/MBox.Platform.Infrastructure/ApplicationContext.Procedures.cs"
                "src/MBox.Platform.Infrastructure/ApplicationContext.Views.cs"
            )
            ;;
        *)
            echo "Iteration $ITERATION: Extended Analysis"
            # Find files dynamically
            mapfile -t TARGET_FILES < <(find "$MBOX_PATH/src" -name "*.cs" -type f | grep -E "(Service|Context|Repository)" | head -10)
            ;;
    esac
    
    # Copy files and track what was actually found
    COPIED_FILES=()
    MISSING_FILES=()
    
    for file in "${TARGET_FILES[@]}"; do
        full_path="$MBOX_PATH/$file"
        if [[ -f "$full_path" ]] && ! is_gitignored "$file"; then
            # Create directory structure
            target_dir="$ANALYSIS_INPUT/$(dirname "$file")"
            mkdir -p "$target_dir"
            
            # Copy file
            cp "$full_path" "$ANALYSIS_INPUT/$file"
            COPIED_FILES+=("$file")
            echo -e "  ${GREEN}✓${NC} Copied: $file"
        else
            MISSING_FILES+=("$file")
            if is_gitignored "$file"; then
                echo -e "  ${YELLOW}⚠${NC} Skipped (gitignored): $file"
            else
                echo -e "  ${RED}✗${NC} Missing: $file"
            fi
        fi
    done
    
    echo -e "\n${GREEN}Files copied: ${#COPIED_FILES[@]}${NC}"
    echo -e "${RED}Files missing/skipped: ${#MISSING_FILES[@]}${NC}"
}

# Function to run the analysis
run_analysis() {
    echo -e "\n${YELLOW}Phase 2: Running SQL dependency analysis...${NC}"
    
    local output_file="$ANALYSIS_OUTPUT/iteration-${ITERATION}-analysis-${TIMESTAMP}.sql"
    local log_file="./logs/iteration-${ITERATION}-${TIMESTAMP}.log"
    
    echo "Analysis output: $output_file"
    echo "Log file: $log_file"
    
    # Run the working quick analyzer
    python3 quick-sql-analyzer.py \
        --directory "$ANALYSIS_INPUT" \
        --output "$output_file" \
        --format sql
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓ Analysis completed successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Analysis failed with exit code $exit_code${NC}"
        return $exit_code
    fi
}

# Function to evaluate results
evaluate_results() {
    echo -e "\n${YELLOW}Phase 3: Evaluating analysis results...${NC}"
    
    local output_file="$ANALYSIS_OUTPUT/iteration-${ITERATION}-analysis-${TIMESTAMP}.sql"
    local eval_file="$ANALYSIS_OUTPUT/iteration-${ITERATION}-evaluation-${TIMESTAMP}.md"
    
    if [[ ! -f "$output_file" ]]; then
        echo -e "${RED}✗ No analysis output file found${NC}"
        return 1
    fi
    
    # Count results
    local total_lines=$(wc -l < "$output_file" 2>/dev/null || echo "0")
    local sql_references=$(grep -c "SELECT\|INSERT\|UPDATE\|DELETE\|CREATE" "$output_file" 2>/dev/null || echo "0")
    local ef_references=$(grep -c "DbContext\|DbSet\|FromSqlRaw" "$output_file" 2>/dev/null || echo "0")
    local connection_refs=$(grep -c "SqlConnection\|ConnectionString" "$output_file" 2>/dev/null || echo "0")
    
    # Generate evaluation report
    cat > "$eval_file" << EOF
# MBox Platform Analysis Evaluation - Iteration $ITERATION

**Analysis Date:** $(date)
**Files Analyzed:** ${#COPIED_FILES[@]}
**Output File:** $(basename "$output_file")

## Analysis Statistics

- **Total lines in output:** $total_lines
- **SQL statement references:** $sql_references
- **Entity Framework references:** $ef_references
- **Connection string references:** $connection_refs

## Files Analyzed

EOF

    for file in "${COPIED_FILES[@]}"; do
        echo "- $file" >> "$eval_file"
    done
    
    cat >> "$eval_file" << EOF

## Missing/Skipped Files

EOF

    for file in "${MISSING_FILES[@]}"; do
        echo "- $file" >> "$eval_file"
    done
    
    cat >> "$eval_file" << EOF

## Key Findings

### SQL Patterns Found
$(grep -i "SELECT\|INSERT\|UPDATE\|DELETE" "$output_file" 2>/dev/null | head -5 | sed 's/^/- /')

### Entity Framework Usage
$(grep -i "DbContext\|DbSet\|FromSqlRaw" "$output_file" 2>/dev/null | head -5 | sed 's/^/- /')

## Recommendations for Next Iteration

EOF

    # Generate recommendations based on findings
    if [[ $sql_references -gt 0 ]]; then
        echo "- ✓ SQL references found - continue with database-heavy components" >> "$eval_file"
    else
        echo "- ⚠ No SQL references found - expand to more data-centric files" >> "$eval_file"
    fi
    
    if [[ $ef_references -gt 0 ]]; then
        echo "- ✓ Entity Framework usage detected - analyze related entity files" >> "$eval_file"
    else
        echo "- ⚠ No EF usage found - check infrastructure and repository files" >> "$eval_file"
    fi
    
    if [[ $connection_refs -gt 0 ]]; then
        echo "- ✓ Connection references found - analyze configuration files" >> "$eval_file"
    else
        echo "- ⚠ No connection references - check appsettings and startup files" >> "$eval_file"
    fi
    
    cat >> "$eval_file" << EOF

## Suggested Next Files

Based on this iteration's findings, consider analyzing:

- Entity configuration files (if EF usage found)
- Repository pattern implementations
- Data access layer components
- Configuration and startup files
- Migration files
- Stored procedure wrapper files

## Quality Metrics

- **Coverage:** ${#COPIED_FILES[@]} files analyzed
- **Success Rate:** $(( (${#COPIED_FILES[@]} * 100) / (${#COPIED_FILES[@]} + ${#MISSING_FILES[@]}) ))%
- **SQL Density:** $(( $sql_references > 0 ? $sql_references / ${#COPIED_FILES[@]} : 0 )) refs/file

EOF
    
    echo -e "${GREEN}✓ Evaluation completed${NC}"
    echo -e "Results: $total_lines lines, $sql_references SQL refs, $ef_references EF refs"
    echo -e "Report: $eval_file"
    
    return 0
}

# Function to suggest improvements
suggest_improvements() {
    echo -e "\n${YELLOW}Phase 4: Suggesting improvements...${NC}"
    
    local suggestions_file="$ANALYSIS_OUTPUT/iteration-${ITERATION}-suggestions-${TIMESTAMP}.md"
    
    cat > "$suggestions_file" << EOF
# Analysis Improvement Suggestions - Iteration $ITERATION

## Configuration Tuning

Based on this iteration's results, consider these config adjustments:

### For Low SQL Detection:
\`\`\`json
{
  "SqlAnalysis": {
    "DetectDynamicSql": true,
    "AnalyzeStringConcatenation": true,
    "ConfidenceThreshold": 30
  }
}
\`\`\`

### For High False Positives:
\`\`\`json
{
  "SqlAnalysis": {
    "ConfidenceThreshold": 70,
    "IncludeSystemObjects": false
  }
}
\`\`\`

## File Selection Strategy

### Next Iteration Should Include:
1. **High Priority:**
   - \`*Repository.cs\` files
   - \`*Context.cs\` files
   - \`*Service.cs\` files with "Data" in path

2. **Medium Priority:**
   - Migration files
   - Configuration files
   - Startup/Program files

3. **Low Priority:**
   - Controller files
   - Model/DTO files
   - Test files

## Command Improvements

### Enhanced Analysis Command:
\`\`\`bash
python3 sql_analyzer.py \\
    --config-file "$CONFIG_FILE" \\
    --directory "$ANALYSIS_INPUT" \\
    --output-file "$output_file" \\
    --export-format json \\
    --log-level DEBUG \\
    --parallel \\
    --validate-objects
\`\`\`

## Quality Assurance

- [ ] Verify all copied files are legitimate source files
- [ ] Check for adequate Entity Framework detection
- [ ] Ensure connection string analysis is working
- [ ] Validate SQL pattern recognition accuracy

EOF
    
    echo -e "${GREEN}✓ Suggestions generated${NC}"
    echo -e "Suggestions: $suggestions_file"
}

# Function to prepare next iteration
prepare_next_iteration() {
    echo -e "\n${YELLOW}Phase 5: Preparing for next iteration...${NC}"
    
    local next_iteration=$((ITERATION + 1))
    local next_script="./run-iteration-${next_iteration}.sh"
    
    cat > "$next_script" << EOF
#!/bin/bash
# Auto-generated script for iteration $next_iteration
./analyze-mbox-iterative.sh $next_iteration
EOF
    
    chmod +x "$next_script"
    
    echo -e "${GREEN}✓ Next iteration script created: $next_script${NC}"
    echo -e "\nTo run next iteration: ${BLUE}./$next_script${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Starting iteration $ITERATION analysis...${NC}\n"
    
    # Validate prerequisites
    if [[ ! -d "$MBOX_PATH" ]]; then
        echo -e "${RED}✗ MBox platform directory not found: $MBOX_PATH${NC}"
        exit 1
    fi
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}✗ Configuration file not found: $CONFIG_FILE${NC}"
        exit 1
    fi
    
    # Run analysis phases
    copy_target_files || exit 1
    run_analysis || exit 1
    evaluate_results || exit 1
    suggest_improvements || exit 1
    prepare_next_iteration || exit 1
    
    echo -e "\n${GREEN}================================${NC}"
    echo -e "${GREEN}Iteration $ITERATION completed successfully!${NC}"
    echo -e "${GREEN}Results available in: $ANALYSIS_OUTPUT${NC}"
    echo -e "${GREEN}================================${NC}"
    
    # Show quick summary
    echo -e "\n${BLUE}Quick Summary:${NC}"
    echo -e "Files analyzed: ${#COPIED_FILES[@]}"
    echo -e "Output directory: $ANALYSIS_OUTPUT"
    echo -e "Next iteration: $((ITERATION + 1))"
}

# Run main function
main "$@"