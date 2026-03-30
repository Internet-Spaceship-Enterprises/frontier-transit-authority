#!/bin/bash

# Directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
WORKSPACE_DIR="$SCRIPT_DIR/../../.."
output=$(sui client test-publish --build-env testnet --pubfile-path $WORKSPACE_DIR/builder-scaffold/deployments/localnet/Pub.localnet.toml --json)

echo "$output" > deploy.json
packageId=$(echo "$output" | jq -r '.objectChanges | first(.[] | select(.type == "published")) | .packageId')
fgnId=$(echo "$output" | jq -r '.objectChanges | first(.[] | select((.objectType? // "") | endswith("::fgn::FrontierGateNetwork"))) | .objectId')

echo "
export const FGN_PACKAGE_ID = \"$packageId\";
export const FGN_OBJECT_ID = \"$fgnId\";
" > "$WORKSPACE_DIR/world-contracts/ts-scripts/fgn/config.ts"
