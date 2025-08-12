#!/bin/bash

# Iteration 6 - SQL-Focused Analysis
echo "Running iteration 6: SQL-focused analysis..."

MBOX_PATH="/mnt/d/dev2/mbox-platform"
ANALYSIS_INPUT="./analysis-input/mbox-sample"
ANALYSIS_OUTPUT="./analysis-output/mbox-platform"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Clear previous iteration
rm -rf "$ANALYSIS_INPUT"/*
mkdir -p "$ANALYSIS_INPUT"

# Target SQL-heavy files
TARGET_FILES=(
    "src/MBox.Platform.Infrastructure/ApplicationContext.Functions.cs"
    "src/MBox.Platform.Host.Functions/InsertInto/InsertIntoTAcceptedDaily.cs"
    "src/MBox.Platform.Host.Functions/InsertInto/InsertIntoTMachineStops.cs"
    "src/MBox.Platform.Host.Functions/Events/ComputeWorkingTimeEvents.cs"
    "src/MBox.Platform.Events/ProcessedEvents/GenerateAvailableEventWhenWorkingTimeChanges.cs"
    "src/MBox.Platform.Events/ProcessedEvents/HandleBarcodeActivities.cs"
)

echo "Iteration 6: SQL-Focused Analysis"
echo "Target files with likely SQL patterns..."

COPIED_FILES=()
for file in "${TARGET_FILES[@]}"; do
    full_path="$MBOX_PATH/$file"
    if [[ -f "$full_path" ]]; then
        target_dir="$ANALYSIS_INPUT/$(dirname "$file")"
        mkdir -p "$target_dir"
        cp "$full_path" "$ANALYSIS_INPUT/$file"
        COPIED_FILES+=("$file")
        echo "✓ Copied: $file"
    else
        echo "✗ Missing: $file"
    fi
done

echo ""
echo "Files copied: ${#COPIED_FILES[@]}"

if [[ ${#COPIED_FILES[@]} -gt 0 ]]; then
    # Run analysis
    output_file="$ANALYSIS_OUTPUT/iteration-6-sql-focused-${TIMESTAMP}.sql"
    echo "Running analysis..."
    
    python3 quick-sql-analyzer.py \
        --directory "$ANALYSIS_INPUT" \
        --output "$output_file" \
        --format sql
    
    echo ""
    echo "Analysis complete!"
    echo "Results: $output_file"
    
    # Quick summary
    if [[ -f "$output_file" ]]; then
        echo ""
        echo "Quick Summary:"
        echo "=============="
        grep "Total:" "$output_file" || echo "No summary found"
        echo ""
        echo "Sample findings:"
        grep -A 3 "EntityFramework\|ADO.NET\|SQL" "$output_file" | head -10
    fi
else
    echo "No files found to analyze!"
fi