#!/bin/bash
ITERATION=5
MBOX_PATH="/mnt/d/dev2/mbox-platform"
ANALYSIS_INPUT="./analysis-input/mbox-sample"
ANALYSIS_OUTPUT="./analysis-output/mbox-platform"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo "Custom Iteration 5: Functions and Services Analysis"

# Clear previous iteration
rm -rf "$ANALYSIS_INPUT"/*
mkdir -p "$ANALYSIS_INPUT"

# Copy our target files
TARGET_FILES=(
    "src/MBox.Platform.Host.Functions/Events/ComputeCycleTimeEvents.cs"
    "src/MBox.Platform.Host.Functions/Events/ComputeScheduleEvents.cs"
    "src/MBox.Platform.Host.Functions/InsertInto/InsertIntoDailyProduction.cs"
    "src/MBox.Platform.Host.Functions/InsertInto/InsertIntoMetrics.cs"
    "src/MBox.Platform.Services/UnitOfWorkService.cs"
)

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

echo "Files copied: ${#COPIED_FILES[@]}"

# Run analysis
output_file="$ANALYSIS_OUTPUT/iteration-5-analysis-${TIMESTAMP}.sql"
python3 quick-sql-analyzer.py \
    --directory "$ANALYSIS_INPUT" \
    --output "$output_file" \
    --format sql

echo "Analysis complete! Results in: $output_file"
