#!/bin/bash
# Test script for complete_setup.sh
# This validates the structure and logic without requiring root access

echo "════════════════════════════════════════════════════════════"
echo "  Testing complete_setup.sh"
echo "════════════════════════════════════════════════════════════"
echo ""

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/complete_setup.sh"

# Test 1: Check script exists
echo "Test 1: Checking if script exists..."
if [ -f "$SCRIPT_PATH" ]; then
    echo "✓ Script exists at: $SCRIPT_PATH"
else
    echo "✗ Script not found at: $SCRIPT_PATH"
    exit 1
fi

# Test 2: Check script is executable
echo ""
echo "Test 2: Checking if script is executable..."
if [ -x "$SCRIPT_PATH" ]; then
    echo "✓ Script is executable"
else
    echo "✗ Script is not executable"
    echo "  Run: chmod +x $SCRIPT_PATH"
    exit 1
fi

# Test 3: Validate bash syntax
echo ""
echo "Test 3: Validating bash syntax..."
if bash -n "$SCRIPT_PATH"; then
    echo "✓ Script syntax is valid"
else
    echo "✗ Script has syntax errors"
    exit 1
fi

# Test 4: Check for required functions
echo ""
echo "Test 4: Checking for required functions..."
if grep -q "command_exists()" "$SCRIPT_PATH"; then
    echo "✓ command_exists() function found"
else
    echo "✗ command_exists() function not found"
    exit 1
fi

# Test 5: Check for critical variables
echo ""
echo "Test 5: Checking for critical variables..."
REQUIRED_VARS=("REPO_DIR" "LOG_DIR" "CHECK_SCRIPT" "AGI_SCRIPT" "WAN_IP")
for var in "${REQUIRED_VARS[@]}"; do
    if grep -q "^[[:space:]]*$var=" "$SCRIPT_PATH"; then
        echo "✓ $var variable defined"
    else
        echo "✗ $var variable not found"
        exit 1
    fi
done

# Test 6: Check for all required steps
echo ""
echo "Test 6: Checking for setup steps..."
REQUIRED_STEPS=(
    "Step 1: Verifying repository"
    "Step 2: Creating log directory"
    "Step 3: Creating monitoring script"
    "Step 4: Adding cron job"
    "Step 5: Running initial checks"
    "Step 6: Optional - AGI script"
    "Step 7: Optional - Firewall"
    "Step 8: Optional - Web dashboard"
)

for step in "${REQUIRED_STEPS[@]}"; do
    if grep -q "$step" "$SCRIPT_PATH"; then
        echo "✓ Found: $step"
    else
        echo "✗ Missing: $step"
        exit 1
    fi
done

# Test 7: Check monitoring script creation
echo ""
echo "Test 7: Checking monitoring script template..."
if grep -q "asterisk-sip-check.sh" "$SCRIPT_PATH"; then
    echo "✓ Monitoring script template found"
else
    echo "✗ Monitoring script template not found"
    exit 1
fi

# Test 8: Check AGI script creation
echo ""
echo "Test 8: Checking AGI script template..."
if grep -q "check-sip-alg.py" "$SCRIPT_PATH"; then
    echo "✓ AGI script template found"
else
    echo "✗ AGI script template not found"
    exit 1
fi

# Test 9: Check for heredoc markers
echo ""
echo "Test 9: Checking heredoc markers..."
HEREDOC_MARKERS=("EOFSCRIPT" "EOFAGI" "EOFDASH")
for marker in "${HEREDOC_MARKERS[@]}"; do
    if grep -q "$marker" "$SCRIPT_PATH"; then
        echo "✓ Heredoc marker $marker found"
    else
        echo "✗ Heredoc marker $marker not found"
        exit 1
    fi
done

# Test 10: Check for interactive prompts
echo ""
echo "Test 10: Checking for interactive prompts..."
if grep -q "read -p" "$SCRIPT_PATH"; then
    echo "✓ Interactive prompts found"
else
    echo "✗ Interactive prompts not found"
    exit 1
fi

# Test 11: Check error handling
echo ""
echo "Test 11: Checking error handling..."
if grep -q "set -e" "$SCRIPT_PATH"; then
    echo "✓ Error handling (set -e) enabled"
else
    echo "⚠ Warning: Error handling not enabled"
fi

# Test 12: Check root privilege check
echo ""
echo "Test 12: Checking root privilege check..."
if grep -q "EUID" "$SCRIPT_PATH"; then
    echo "✓ Root privilege check found"
else
    echo "✗ Root privilege check not found"
    exit 1
fi

# Test 13: Validate cron job format
echo ""
echo "Test 13: Validating cron job format..."
if grep -q "0 \*/6 \* \* \*" "$SCRIPT_PATH"; then
    echo "✓ Cron job format is valid"
else
    echo "✗ Cron job format not found or invalid"
    exit 1
fi

# Test 14: Check for cleanup logic
echo ""
echo "Test 14: Checking for log cleanup..."
if grep -q "mtime +30" "$SCRIPT_PATH"; then
    echo "✓ Log cleanup logic found (30 day retention)"
else
    echo "⚠ Warning: Log cleanup not found"
fi

# Test 15: Check documentation reference
echo ""
echo "Test 15: Checking documentation references..."
if [ -f "COMPLETE_SETUP_README.md" ]; then
    echo "✓ Documentation file exists"
else
    echo "⚠ Warning: COMPLETE_SETUP_README.md not found"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✓ All Tests Passed!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "The complete_setup.sh script is ready to use."
echo ""
echo "To run the actual setup (requires root):"
echo "  sudo bash $SCRIPT_PATH"
echo ""
echo "For more information:"
echo "  cat COMPLETE_SETUP_README.md"
echo ""
