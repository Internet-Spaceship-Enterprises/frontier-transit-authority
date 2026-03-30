#!/bin/bash
set -e

# Directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
WORKSPACE_DIR="$SCRIPT_DIR/../../.."

# Publish the contract under Player B
sui client switch --address player-b

output=$(sui client test-upgrade --build-env testnet --pubfile-path $WORKSPACE_DIR/builder-scaffold/deployments/localnet/Pub.localnet.toml --json --verify-deps | tee /dev/tty)

# Switch back to the admin
sui client switch --address admin

echo "$output" > deploy.json
packageId=$(echo "$output" | jq -r '.objectChanges | first(.[] | select(.type == "published")) | .packageId')

sed -i "s|^export const FTA_PACKAGE_ID = .*|export const FTA_PACKAGE_ID = \"$packageId\";|" "$SCRIPT_DIR/ts-scripts/config.ts"
