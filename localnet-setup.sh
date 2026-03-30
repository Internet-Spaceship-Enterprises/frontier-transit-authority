#!/bin/bash
set -e

# Kill all child processes (sui network) when the script exits
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

if ! command -v sui &> /dev/null; then
    echo "You must install the Sui client before this script can be used" >2
    exit 1
fi
if ! command -v jq &> /dev/null; then
    echo "You must install jq before this script can be used" >2
    exit 1
fi


# Directory of the script
SETUP_SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
WORKSPACE_DIR="$SETUP_SCRIPT_DIR/.."

source "$WORKSPACE_DIR/world-contracts/scripts/lib.sh"

# Start the localnet chain
sui start --with-faucet --force-regenesis &

# Create a specific network alias if it doesn't exist
NETWORK="localnet"
RPC_URL="http://127.0.0.1:9000"
if ! $(sui client envs --json | jq --arg ALIAS "$NETWORK" '.[0] | any(.alias == $ALIAS)'); then 
    echo "Creating new environment: $NETWORK"
    while true; do
        set +e
        output=$(sui client new-env --alias="$NETWORK" --rpc $RPC_URL)
        if [ $? -eq 0 ]; then
            echo $output
            break
        fi
        sleep 1
    done
fi

# Wait until the chain is up and running
while true; do
    set +e
    sui client chain-identifier > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        break
    fi
    sleep 1
done
set -e

chain_id=$(sui client chain-identifier)
# Update this package's Move.toml file
sed -i "/^\[environments\]/,/^\[/{s/^[[:space:]]*$NETWORK[[:space:]]*=.*/$NETWORK = \"$chain_id\"/}" "$SETUP_SCRIPT_DIR/sui/fta/Move.toml"

# Ensure the correct network is selected
sui client switch --env $NETWORK

# Function to create a new address IF it doesn't exist
create_address () {
    if ! $(sui client addresses --json | jq -e --arg ALIAS "$1" '.addresses | any(.[0] == $ALIAS)'); then 
        sui client new-address ed25519 $1
    fi
    sui client switch --address $1
    while true; do
        set +e
        output=$(sui client faucet)
        if [ $? -eq 0 ]; then
            echo $output
            break
        fi
        sleep 1
    done
    set -e
}

# Create the admin, player A, and player B addresses if they don't exist
create_address "admin"
addr_admin=$(sui client active-address)
create_address "player-a"
addr_player_a=$(sui client active-address)
create_address "player-b"
addr_player_b=$(sui client active-address)

# Switch back to admin for world deployment
sui client switch --address admin

# Clean up deployment directories
rm -rf "$WORKSPACE_DIR/world-contracts/deployments/$NETWORK/"
mkdir -p "$WORKSPACE_DIR/builder-scaffold/deployments/$NETWORK/"
rm -rf "$WORKSPACE_DIR/builder-scaffold/deployments/$NETWORK/"
mkdir -p "$WORKSPACE_DIR/world-contracts/deployments/$NETWORK/"
rm -f $WORKSPACE_DIR/builder-scaffold/test-resources.json

echo "
# ============================================
# SUI NETWORK
# ============================================
SUI_NETWORK=$NETWORK

# Custom RPC URL (optional, defaults based on network)
SUI_RPC_URL=$RPC_URL

# ============================================
# KEYS & ADDRESSES
# ============================================
ADMIN_ADDRESS=$addr_admin
SPONSOR_ADDRESSES=$addr_admin
PLAYER_A_ADDRESS=$addr_player_a
PLAYER_B_ADDRESS=$addr_player_b

ADMIN_PRIVATE_KEY=$(sui keytool export --json --key-identity admin | jq -r .exportedPrivateKey)
GOVERNOR_PRIVATE_KEY=$(sui keytool export --json --key-identity admin | jq -r .exportedPrivateKey)
PLAYER_A_PRIVATE_KEY=$(sui keytool export --json --key-identity player-a | jq -r .exportedPrivateKey)
PLAYER_B_PRIVATE_KEY=$(sui keytool export --json --key-identity player-b | jq -r .exportedPrivateKey)

# ============================================
# PACKAGE IDS (populated after deployment)
# ============================================
WORLD_PACKAGE_ID=
BUILDER_PACKAGE_ID=
EXTENSION_CONFIG_ID=
ASSETS_PACKAGE_ID=
EVE_CURRENCY_OBJECT_ID=
EVE_TREASURY_OBJECT_ID=
EVE_COIN_OBJECT_ID=
EVE_ADMIN_CAP_ID=

# ============================================
# TENANT
# ============================================
TENANT=dev

# ============================================
# WORLD CONFIGURATION VALUES
# ============================================
# Fuel Configuration
FUEL_TYPE_IDS=78437,78515,78516,84868,88319,88335
FUEL_EFFICIENCIES=90,80,40,40,15,10

# Energy Configuration
ASSEMBLY_TYPE_IDS=77917,84556,84955,87119,87120,88063,88064,88067,88068,88069,88070,88071,88082,88083,90184,91978,92279,92401,92404
ENERGY_REQUIRED_VALUES=500,10,950,50,250,100,200,100,200,100,200,300,50,100,1,100,10,20,40

# Gate Configuration
GATE_TYPE_IDS=88086,84955
MAX_DISTANCES=520340175991902420,1040680351983804840
" > "$SETUP_SCRIPT_DIR/.env" 

# Copy the .env file to the relevant packages
cp "$SETUP_SCRIPT_DIR/.env" "$WORKSPACE_DIR/world-contracts/.env" 
cp "$SETUP_SCRIPT_DIR/.env" "$WORKSPACE_DIR/builder-scaffold/.env" 

cd "$WORKSPACE_DIR/world-contracts"
pnpm install
pnpm deploy-world $NETWORK
pnpm configure-world $NETWORK
# Publish the assets (EVE token)
publish assets "deployments/$NETWORK/assets_package.json" "$NETWORK" "$WORKSPACE_DIR/world-contracts/contracts/world/Pub.localnet.toml"
assets_package_id=$(cat $WORKSPACE_DIR/world-contracts/deployments/$NETWORK/assets_package.json | jq -r '.objectChanges | first(.[] | select(.type == "published")) | .packageId')
eve_currency_object_id=$(cat $WORKSPACE_DIR/world-contracts/deployments/$NETWORK/assets_package.json | jq -r '.objectChanges | first(.[] | select((.objectType? // "") | startswith("0x2::coin_registry::Currency"))) | .objectId')
eve_coin_object_id=$(cat $WORKSPACE_DIR/world-contracts/deployments/$NETWORK/assets_package.json | jq -r '.objectChanges | first(.[] | select((.objectType? // "") | startswith("0x2::coin::Coin"))) | .objectId')
eve_treasury_object_id=$(cat $WORKSPACE_DIR/world-contracts/deployments/$NETWORK/assets_package.json | jq -r '.objectChanges | first(.[] | select((.objectType? // "") | endswith("::EVE::EveTreasury"))) | .objectId')
eve_admin_cap_id=$(cat $WORKSPACE_DIR/world-contracts/deployments/$NETWORK/assets_package.json | jq -r '.objectChanges | first(.[] | select((.objectType? // "") | endswith("::EVE::AdminCap"))) | .objectId')
# Set the delay to 0 since we're just using localnet
# This makes the deployment WAY faster
DELAY_SECONDS=0 pnpm create-test-resources $NETWORK

# Update the .env files with the package IDs
world_package_id=$(cat $WORKSPACE_DIR/world-contracts/deployments/$NETWORK/extracted-object-ids.json | jq -r ".world.packageId")
sed -i "s/WORLD_PACKAGE_ID=/WORLD_PACKAGE_ID=$world_package_id/g" "$SETUP_SCRIPT_DIR/.env"
sed -i "s/ASSETS_PACKAGE_ID=/ASSETS_PACKAGE_ID=$assets_package_id/g" "$SETUP_SCRIPT_DIR/.env"
sed -i "s/EVE_CURRENCY_OBJECT_ID=/EVE_CURRENCY_OBJECT_ID=$eve_currency_object_id/g" "$SETUP_SCRIPT_DIR/.env"
sed -i "s/EVE_COIN_OBJECT_ID=/EVE_COIN_OBJECT_ID=$eve_coin_object_id/g" "$SETUP_SCRIPT_DIR/.env"
sed -i "s/EVE_TREASURY_OBJECT_ID=/EVE_TREASURY_OBJECT_ID=$eve_treasury_object_id/g" "$SETUP_SCRIPT_DIR/.env"
sed -i "s/EVE_ADMIN_CAP_ID=/EVE_ADMIN_CAP_ID=$eve_admin_cap_id/g" "$SETUP_SCRIPT_DIR/.env"
cp "$SETUP_SCRIPT_DIR/.env" "$WORKSPACE_DIR/world-contracts/.env" 
cp "$SETUP_SCRIPT_DIR/.env" "$WORKSPACE_DIR/builder-scaffold/.env"  

# Finalize the EVE currency
pnpm tsx $WORKSPACE_DIR/world-contracts/ts-scripts/assets/finalize-eve-currency.ts
# Transfer some to player A
pnpm tsx $SETUP_SCRIPT_DIR/sui/fta/ts-scripts/transfer-eve.ts

# Copy over deployment artifacts
cp -r "$WORKSPACE_DIR/world-contracts/deployments/$NETWORK" "$WORKSPACE_DIR/builder-scaffold/deployments/"
cp "$WORKSPACE_DIR/world-contracts/test-resources.json" "$WORKSPACE_DIR/builder-scaffold/test-resources.json"
cp "$WORKSPACE_DIR/world-contracts/contracts/world/Pub.localnet.toml" "$WORKSPACE_DIR/builder-scaffold/deployments/$NETWORK/Pub.localnet.toml"

echo "Everything running!
    Chain ID: $chain_id
"
read -p "Press ENTER to exit..."
