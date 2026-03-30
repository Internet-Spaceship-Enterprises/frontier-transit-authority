#!/bin/bash

# Directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
WORKSPACE_DIR="$SCRIPT_DIR/../../.."
output=$(sui client test-publish --build-env testnet --pubfile-path $WORKSPACE_DIR/builder-scaffold/deployments/localnet/Pub.localnet.toml --json)

echo "$output" > deploy.json
packageId=$(echo "$output" | jq -r '.objectChanges | first(.[] | select(.type == "published")) | .packageId')
ftaId=$(echo "$output" | jq -r '.objectChanges | first(.[] | select((.objectType? // "") | endswith("::fta::FrontierTransitAuthority"))) | .objectId')

echo "
export const FTA_PACKAGE_ID = \"$packageId\";
export const FTA_OBJECT_ID = \"$ftaId\";
" > "$SCRIPT_DIR/ts-scripts/config.ts"
