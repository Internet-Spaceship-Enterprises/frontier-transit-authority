#!/bin/bash
set -e

# Directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
WORKSPACE_DIR="$SCRIPT_DIR/../../.."

# Publish the contract under Player B
sui client switch --address player-b

output=$(sui client test-publish --build-env testnet --pubfile-path $WORKSPACE_DIR/builder-scaffold/deployments/localnet/Pub.localnet.toml --json)

# Switch back to the admin
sui client switch --address admin

echo "$output" > deploy.json
packageId=$(echo "$output" | jq -r '.objectChanges | first(.[] | select(.type == "published")) | .packageId')
ftaId=$(echo "$output" | jq -r '.objectChanges | first(.[] | select((.objectType? // "") | endswith("::fta::FrontierTransitAuthority"))) | .objectId')
devCapId=$(echo "$output" | jq -r '.objectChanges | first(.[] | select((.objectType? // "") | endswith("::fta::DeveloperCap"))) | .objectId')

echo "
export const FTA_PACKAGE_ID = \"$packageId\";
export const FTA_OBJECT_ID = \"$ftaId\";
export const FTA_DEV_CAP_ID = \"$devCapId\";
" > "$SCRIPT_DIR/ts-scripts/config.ts"

pushd  $WORKSPACE_DIR/frontier-gate-network
pnpm set-owner-character
popd
