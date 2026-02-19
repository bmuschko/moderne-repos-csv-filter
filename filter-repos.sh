#!/bin/bash

# Script to filter repos-lock.csv based on cloneUrl values from filter.csv
# Usage: ./filter-repos.sh

FILTER_FILE="filter.csv"
REPOS_FILE="repos-lock.csv"
OUTPUT_FILE="output.csv"

# Check if input files exist
if [[ ! -f "$FILTER_FILE" ]]; then
    echo "Error: $FILTER_FILE not found"
    exit 1
fi

if [[ ! -f "$REPOS_FILE" ]]; then
    echo "Error: $REPOS_FILE not found"
    exit 1
fi

# Use awk to perform the filtering efficiently
# - First, read all cloneUrl values from filter.csv (column 1) into an array
# - Then, process repos-lock.csv and output rows where cloneUrl (column 4) matches
awk -F',' '
    NR == FNR {
        # Processing filter.csv (first file)
        if (NR > 1) {
            # Remove surrounding quotes if present
            url = $1
            gsub(/^"/, "", url)
            gsub(/"$/, "", url)
            filter_urls[url] = 1
        }
        next
    }
    # Processing repos-lock.csv (second file)
    FNR == 1 {
        # Print header
        print
        next
    }
    {
        # Extract cloneUrl (4th column) and check for match
        url = $4
        gsub(/^"/, "", url)
        gsub(/"$/, "", url)
        if (url in filter_urls) {
            print
        }
    }
' "$FILTER_FILE" "$REPOS_FILE" > "$OUTPUT_FILE"

# Count results
total_filter=$(tail -n +2 "$FILTER_FILE" | wc -l | xargs)
total_output=$(tail -n +2 "$OUTPUT_FILE" | wc -l | xargs)

echo "Filtering complete!"
echo "Filter entries: $total_filter"
echo "Matching rows found: $total_output"
echo "Output written to: $OUTPUT_FILE"
