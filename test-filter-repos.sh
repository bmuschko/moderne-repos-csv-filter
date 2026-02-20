#!/bin/bash

# Test script for filter-repos.sh
# Usage: ./test-filter-repos.sh

TEST_DIR="test_tmp"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test directory
setup() {
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    cp "$SCRIPT_DIR/filter-repos.sh" "$TEST_DIR/"
    cd "$TEST_DIR"
}

# Cleanup test directory
cleanup() {
    cd "$SCRIPT_DIR"
    rm -rf "$TEST_DIR"
}

# Assert function
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}PASS${NC}: $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        ((TESTS_FAILED++))
    fi
}

assert_file_contains() {
    local file="$1"
    local content="$2"
    local message="$3"

    if grep -qF "$content" "$file"; then
        echo -e "${GREEN}PASS${NC}: $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $message"
        echo "  File '$file' does not contain: $content"
        ((TESTS_FAILED++))
    fi
}

assert_file_not_contains() {
    local file="$1"
    local content="$2"
    local message="$3"

    if ! grep -qF "$content" "$file"; then
        echo -e "${GREEN}PASS${NC}: $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $message"
        echo "  File '$file' should not contain: $content"
        ((TESTS_FAILED++))
    fi
}

# Test 1: Basic filtering with matching rows
test_basic_filtering() {
    echo "--- Test 1: Basic filtering with matching rows ---"

    # Create filter.csv
    cat > filter.csv << 'EOF'
cloneUrl,defaultBranch,origin
https://github.com/org/repo1.git,main,github
https://github.com/org/repo3.git,master,github
EOF

    # Create repos-lock.csv
    cat > repos-lock.csv << 'EOF'
origin,path,branch,cloneUrl,changeset,publishUri,org1,org2,org3,org4,org5,org6,org7,org8
github,/path/to/repo1,main,https://github.com/org/repo1.git,abc123,http://publish1,o1,o2,o3,o4,o5,o6,o7,o8
github,/path/to/repo2,main,https://github.com/org/repo2.git,def456,http://publish2,o1,o2,o3,o4,o5,o6,o7,o8
github,/path/to/repo3,master,https://github.com/org/repo3.git,ghi789,http://publish3,o1,o2,o3,o4,o5,o6,o7,o8
github,/path/to/repo4,develop,https://github.com/org/repo4.git,jkl012,http://publish4,o1,o2,o3,o4,o5,o6,o7,o8
EOF

    ./filter-repos.sh > /dev/null

    # Verify output
    local line_count=$(wc -l < output.csv | xargs)
    assert_equals "3" "$line_count" "Output should have 3 lines (1 header + 2 matching rows)"

    assert_file_contains output.csv "origin,path,branch,cloneUrl" "Output should contain header"
    assert_file_contains output.csv "https://github.com/org/repo1.git" "Output should contain repo1"
    assert_file_contains output.csv "https://github.com/org/repo3.git" "Output should contain repo3"
    assert_file_not_contains output.csv "https://github.com/org/repo2.git" "Output should not contain repo2"
    assert_file_not_contains output.csv "https://github.com/org/repo4.git" "Output should not contain repo4"

    rm -f filter.csv repos-lock.csv output.csv
}

# Test 2: No matching rows
test_no_matches() {
    echo ""
    echo "--- Test 2: No matching rows ---"

    cat > filter.csv << 'EOF'
cloneUrl,defaultBranch,origin
https://github.com/org/nonexistent.git,main,github
EOF

    cat > repos-lock.csv << 'EOF'
origin,path,branch,cloneUrl,changeset,publishUri,org1,org2,org3,org4,org5,org6,org7,org8
github,/path/to/repo1,main,https://github.com/org/repo1.git,abc123,http://publish1,o1,o2,o3,o4,o5,o6,o7,o8
EOF

    ./filter-repos.sh > /dev/null

    local line_count=$(wc -l < output.csv | xargs)
    assert_equals "1" "$line_count" "Output should have only header when no matches"

    rm -f filter.csv repos-lock.csv output.csv
}

# Test 3: All rows match
test_all_match() {
    echo ""
    echo "--- Test 3: All rows match ---"

    cat > filter.csv << 'EOF'
cloneUrl,defaultBranch,origin
https://github.com/org/repo1.git,main,github
https://github.com/org/repo2.git,main,github
EOF

    cat > repos-lock.csv << 'EOF'
origin,path,branch,cloneUrl,changeset,publishUri,org1,org2,org3,org4,org5,org6,org7,org8
github,/path/to/repo1,main,https://github.com/org/repo1.git,abc123,http://publish1,o1,o2,o3,o4,o5,o6,o7,o8
github,/path/to/repo2,main,https://github.com/org/repo2.git,def456,http://publish2,o1,o2,o3,o4,o5,o6,o7,o8
EOF

    ./filter-repos.sh > /dev/null

    local line_count=$(wc -l < output.csv | xargs)
    assert_equals "3" "$line_count" "Output should have all rows when all match"

    rm -f filter.csv repos-lock.csv output.csv
}

# Test 4: Preserves all columns
test_preserves_columns() {
    echo ""
    echo "--- Test 4: Preserves all columns ---"

    cat > filter.csv << 'EOF'
cloneUrl,defaultBranch,origin
https://github.com/org/repo1.git,main,github
EOF

    cat > repos-lock.csv << 'EOF'
origin,path,branch,cloneUrl,changeset,publishUri,org1,org2,org3,org4,org5,org6,org7,org8
github,/path/to/repo1,main,https://github.com/org/repo1.git,abc123,http://publish1,a1,b2,c3,d4,e5,f6,g7,h8
EOF

    ./filter-repos.sh > /dev/null

    # Check that the full row is preserved
    assert_file_contains output.csv "github,/path/to/repo1,main,https://github.com/org/repo1.git,abc123,http://publish1,a1,b2,c3,d4,e5,f6,g7,h8" "Output should preserve all columns"

    rm -f filter.csv repos-lock.csv output.csv
}

# Test 5: Handles quoted values
test_quoted_values() {
    echo ""
    echo "--- Test 5: Handles quoted values ---"

    cat > filter.csv << 'EOF'
cloneUrl,defaultBranch,origin
"https://github.com/org/repo1.git",main,github
EOF

    cat > repos-lock.csv << 'EOF'
origin,path,branch,cloneUrl,changeset,publishUri,org1,org2,org3,org4,org5,org6,org7,org8
github,/path/to/repo1,main,"https://github.com/org/repo1.git",abc123,http://publish1,o1,o2,o3,o4,o5,o6,o7,o8
EOF

    ./filter-repos.sh > /dev/null

    local line_count=$(wc -l < output.csv | xargs)
    assert_equals "2" "$line_count" "Output should match quoted URLs"

    rm -f filter.csv repos-lock.csv output.csv
}

# Test 6: Skips comment lines in repos-lock.csv
test_skips_comments() {
    echo ""
    echo "--- Test 6: Skips comment lines in repos-lock.csv ---"

    cat > filter.csv << 'EOF'
cloneUrl,defaultBranch,origin
https://github.com/org/repo1.git,main,github
EOF

    # Create repos-lock.csv with comment lines at the top
    cat > repos-lock.csv << 'EOF'
# This is a comment
# Another comment line
origin,path,branch,cloneUrl,changeset,publishUri,org1,org2,org3,org4,org5,org6,org7,org8
github,/path/to/repo1,main,https://github.com/org/repo1.git,abc123,http://publish1,o1,o2,o3,o4,o5,o6,o7,o8
github,/path/to/repo2,main,https://github.com/org/repo2.git,def456,http://publish2,o1,o2,o3,o4,o5,o6,o7,o8
EOF

    ./filter-repos.sh > /dev/null

    # Verify output has correct header (not comment)
    local first_line=$(head -1 output.csv)
    if [[ "$first_line" == "origin,path,branch,cloneUrl"* ]]; then
        echo -e "${GREEN}PASS${NC}: Output header is correct (not a comment)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}: Output header should be the CSV header, not a comment"
        echo "  First line: $first_line"
        ((TESTS_FAILED++))
    fi

    # Verify comments are not in output
    assert_file_not_contains output.csv "# This is a comment" "Output should not contain comment lines"

    # Verify correct row count (1 header + 1 matching row)
    local line_count=$(wc -l < output.csv | xargs)
    assert_equals "2" "$line_count" "Output should have 2 lines (1 header + 1 matching row)"

    rm -f filter.csv repos-lock.csv output.csv
}

# Test 7: Missing filter file
test_missing_filter_file() {
    echo ""
    echo "--- Test 7: Missing filter file error handling ---"

    cat > repos-lock.csv << 'EOF'
origin,path,branch,cloneUrl,changeset,publishUri,org1,org2,org3,org4,org5,org6,org7,org8
github,/path/to/repo1,main,https://github.com/org/repo1.git,abc123,http://publish1,o1,o2,o3,o4,o5,o6,o7,o8
EOF

    local output=$(./filter-repos.sh 2>&1 || true)

    if [[ "$output" == *"filter.csv not found"* ]]; then
        echo -e "${GREEN}PASS${NC}: Script reports missing filter.csv"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}: Script should report missing filter.csv"
        ((TESTS_FAILED++))
    fi

    rm -f repos-lock.csv
}

# Test 8: Missing repos-lock file
test_missing_repos_file() {
    echo ""
    echo "--- Test 8: Missing repos-lock file error handling ---"

    cat > filter.csv << 'EOF'
cloneUrl,defaultBranch,origin
https://github.com/org/repo1.git,main,github
EOF

    local output=$(./filter-repos.sh 2>&1 || true)

    if [[ "$output" == *"repos-lock.csv not found"* ]]; then
        echo -e "${GREEN}PASS${NC}: Script reports missing repos-lock.csv"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}: Script should report missing repos-lock.csv"
        ((TESTS_FAILED++))
    fi

    rm -f filter.csv
}

# Main execution
main() {
    echo "========================================"
    echo "Running tests for filter-repos.sh"
    echo "========================================"
    echo ""

    setup

    test_basic_filtering
    test_no_matches
    test_all_match
    test_preserves_columns
    test_quoted_values
    test_skips_comments
    test_missing_filter_file
    test_missing_repos_file

    cleanup

    echo ""
    echo "========================================"
    echo "Test Results"
    echo "========================================"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

main
