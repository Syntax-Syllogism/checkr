#!/bin/bash

# Configuration
ALIAS=$1
PROGRESS_DIR="temp"
PROGRESS_FILE="$PROGRESS_DIR/.reset_scratch_org_progress"

if [ -z "$ALIAS" ]; then
    echo "Usage: $0 <alias>"
    echo "Example: $0 my-scratch-org"
    exit 1
fi

# Ensure progress directory exists
mkdir -p "$PROGRESS_DIR"

# Function to get current progress
get_progress() {
    if [ -f "$PROGRESS_FILE" ]; then
        cat "$PROGRESS_FILE"
    else
        echo "0"
    fi
}

# Function to set progress
set_progress() {
    echo "$1" > "$PROGRESS_FILE"
}

# Ensure we are in the project root
if [ ! -f "sfdx-project.json" ]; then
    echo "Error: This script must be run from the SFDX project root."
    exit 1
fi

STEP=$(get_progress)

# Step 1: Delete existing scratch org if it exists
if [ "$STEP" -lt 1 ]; then
    echo "--- Step 1: Checking for existing scratch org: $ALIAS ---"
    # Check if the org exists in the list using jq for robust parsing
    if sf org list --json | jq -e --arg alias "$ALIAS" '.result | ([.scratchOrgs[], .nonScratchOrgs[]] | any(.alias == $alias))' > /dev/null 2>&1; then
        echo "Org $ALIAS found. Deleting..."
        sf org delete scratch --target-org "$ALIAS" --no-prompt --json
        if [ $? -ne 0 ]; then
            echo "Warning: Potential issue deleting org, continuing anyway..."
        fi
    else
        echo "Org $ALIAS not found. Skipping deletion."
    fi
    set_progress 1
fi

# Step 2: Create new scratch org
if [ "$STEP" -lt 2 ]; then
    echo "--- Step 2: Creating new scratch org: $ALIAS ---"
    
    # Get definition file from sfdx-project.json
    DEFINITION_FILE=$(jq -r '.packageDirectories[] | select(.default==true and .definitionFile != null) | .definitionFile' sfdx-project.json | head -n 1)
    
    if [ -z "$DEFINITION_FILE" ] || [ "$DEFINITION_FILE" == "null" ]; then
        echo "Warning: Could not find definitionFile in sfdx-project.json. Falling back to config/project-scratch-def.json"
        DEFINITION_FILE="config/project-scratch-def.json"
    fi

    echo "Using definition file: $DEFINITION_FILE"

    sf org create scratch \
        --definition-file "$DEFINITION_FILE" \
        --alias "$ALIAS" \
        --duration-days 30 \
        --set-default \
        --wait 20 \
        --json

    if [ $? -ne 0 ]; then
        echo "Error: Failed to create scratch org."
        exit 1
    fi
    set_progress 2
fi

# Step 4: Deploy main project source
if [ "$STEP" -lt 4 ]; then
    echo "--- Step 4: Deploying main project source ---"
    sf project deploy start \
        --target-org "$ALIAS" \
        --ignore-conflicts \
        --json
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to deploy main project source."
        exit 1
    fi
    set_progress 4
fi

# Step 5: Assign CKR_Admin permission set
if [ "$STEP" -lt 5 ]; then
    echo "--- Step 5: Assigning CKR_Admin permission set ---"
    sf org assign permset --name CKR_Admin --target-org "$ALIAS" --json
    if [ $? -ne 0 ]; then
        echo "Note: Permission set assignment failed or was already assigned. Continuing..."
    fi
    set_progress 5
fi

# Step 6: Seed smoke users and data in separate transactions
if [ "$STEP" -lt 6 ]; then
    echo "--- Step 6a: Seeding smoke users ---"
    sf apex run --file scripts/seedSmokeUsers.apex --target-org "$ALIAS" --json
    if [ $? -ne 0 ]; then
        echo "Error: Failed to seed smoke users."
        exit 1
    fi

    echo "--- Step 6b: Seeding smoke data ---"
    sf apex run --file scripts/seedSmokeData.apex --target-org "$ALIAS" --json
    if [ $? -ne 0 ]; then
        echo "Error: Failed to seed smoke data."
        exit 1
    fi
    set_progress 6
fi

echo "--------------------------------------------------"
echo "Successfully reset scratch org: $ALIAS"
echo "--------------------------------------------------"

# Clean up progress file on success
rm "$PROGRESS_FILE"
