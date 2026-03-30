#!/bin/bash
set -e

# Directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
WORKSPACE_DIR="$SCRIPT_DIR/../../.."

# Publish the contract under Player B
sui client switch --address player-b

output=$(sui client test-publish --build-env testnet --pubfile-path $WORKSPACE_DIR/builder-scaffold/deployments/localnet/Pub.localnet.toml --json | tee /dev/tty)

# Switch back to the admin
sui client switch --address admin

echo "$output" > deploy.json
packageId=$(echo "$output" | jq -r '.objectChanges | first(.[] | select(.type == "published")) | .packageId')
ftaId=$(echo "$output" | jq -r '.objectChanges | first(.[] | select((.objectType? // "") | endswith("::fta::FrontierTransitAuthority"))) | .objectId')
originalUpgradeCapId=$(echo "$output" | jq -r '.objectChanges | first(.[] | select((.objectType? // "") == "0x2::package::UpgradeCap")) | .objectId')

echo "
export const FTA_PACKAGE_ID = \"$packageId\";
export const FTA_OBJECT_ID = \"$ftaId\";
export const FTA_ORIGINAL_UPGRADE_CAP_ID = \"$originalUpgradeCapId\";
" > "$SCRIPT_DIR/ts-scripts/config.ts"

cd ../../
pnpm run exchange-upgrade-cap
