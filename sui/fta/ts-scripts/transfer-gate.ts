import "dotenv/config";
import { Transaction } from "@mysten/sui/transactions";
import { bcs } from '@mysten/sui/bcs';
import { MODULES } from "../../../ts-scripts/utils/config";
import { FTA_PACKAGE_ID, FTA_OBJECT_ID } from "./config";
import {
    getEnvConfig,
    handleError,
    hydrateWorldConfig,
    initializeContext,
    requireEnv,
} from "../../../ts-scripts/utils/helper";
import { deriveObjectId } from "../../../ts-scripts/utils/derive-object-id";
import { getGateOwnerCapId, getNetworkNodeOwnerCap, getEnergySourceId, gateNetworkNodeRegistered } from "./utils";
import { GAME_CHARACTER_ID, GATE_ITEM_ID_1, GATE_ITEM_ID_2, NWN_ITEM_ID } from "../../../ts-scripts/utils/constants";

async function prepareTransferGate(
    ctx: ReturnType<typeof initializeContext>,
    tx: Transaction,
    characterId: number,
    gateItemId: bigint,
    gateTransferReceipt: any,
) {
    const { client, keypair, config, address } = ctx;

    const characterObjectId = deriveObjectId(config.objectRegistry, characterId, config.packageId);
    const gateId = deriveObjectId(config.objectRegistry, gateItemId, config.packageId);

    const energySourceId = await getEnergySourceId(gateId, client, config, address);
    if (!energySourceId) {
        throw new Error("Cannot transfer a gate without a network node connected");
    }
    console.log("Energy source ID: ", energySourceId);

    console.log("Gate ID: ", gateId);
    const gateOwnerCapId = await getGateOwnerCapId(gateId, client, config, address);
    if (!gateOwnerCapId) {
        throw new Error("Gate OwnerCap not found (make sure the character owns the gate)");
    }

    const [gateOwnerCap, gateOwnerReceipt] = tx.moveCall({
        target: `${config.packageId}::${MODULES.CHARACTER}::borrow_owner_cap`,
        typeArguments: [`${config.packageId}::${MODULES.GATE}::Gate`],
        arguments: [tx.object(characterObjectId), tx.object(gateOwnerCapId)],
    });
    const prevReceipt = gateTransferReceipt == null ? tx.object.option({
        type: `${FTA_PACKAGE_ID}::transfer::GateTransferReceipt`,
        value: null,
    }) : gateTransferReceipt;

    let transfer_receipt;

    if (await gateNetworkNodeRegistered(gateId, client, address)) {
        // The network node is already registered, no need to transfer it
        transfer_receipt = tx.moveCall({
            target: `${FTA_PACKAGE_ID}::fgn::transfer_gate_only`,
            arguments: [
                tx.object(FTA_OBJECT_ID),
                prevReceipt,
                tx.object(characterObjectId),
                tx.object(gateId),
                gateOwnerCap,
                gateOwnerReceipt,
                tx.object(energySourceId),
                tx.pure.u64(99),
                tx.object(config.energyConfig),
                tx.object("0x6"),
            ],
        });
    } else {
        const nnOwnerCapId = await getNetworkNodeOwnerCap(energySourceId, client, config, address);
        if (!nnOwnerCapId) {
            throw new Error("Gate Network Node Owner Cap not found (make sure the character owns the network node)");
        }
        const [nnOwnerCap, nnOwnerCapReceipt] = tx.moveCall({
            target: `${config.packageId}::${MODULES.CHARACTER}::borrow_owner_cap`,
            typeArguments: [`${config.packageId}::${MODULES.NETWORK_NODE}::NetworkNode`],
            arguments: [tx.object(characterObjectId), tx.object(nnOwnerCapId)],
        });
        // The network node is not registered, so it needs to be transferred too
        transfer_receipt = tx.moveCall({
            target: `${FTA_PACKAGE_ID}::fgn::transfer_gate_and_network_node`,
            arguments: [
                tx.object(FTA_OBJECT_ID),
                gateTransferReceipt,
                tx.object(characterObjectId),
                tx.object(gateId),
                gateOwnerCap,
                gateOwnerReceipt,
                tx.object(energySourceId),
                nnOwnerCap,
                nnOwnerCapReceipt,
                tx.pure.u64(99),
                tx.object(config.energyConfig),
                tx.object("0x6"),
            ],
        });
    }

    return transfer_receipt;
}

async function main() {
    try {
        const env = getEnvConfig();

        const playerKey = requireEnv("PLAYER_A_PRIVATE_KEY");
        const playerCtx = initializeContext(env.network, playerKey);
        await hydrateWorldConfig(playerCtx);

        let tx = new Transaction();
        let transfer_receipt = await prepareTransferGate(playerCtx, tx, GAME_CHARACTER_ID, GATE_ITEM_ID_1, null);
        await prepareTransferGate(playerCtx, tx, GAME_CHARACTER_ID, GATE_ITEM_ID_2, transfer_receipt);


        // const result = await client.signAndExecuteTransaction({
        //     transaction: tx,
        //     signer: keypair,
        //     options: { showObjectChanges: true, showEffects: true, showEvents: true },
        // });

        // console.log("\nGate transferred successfully!");
        // console.log("Transaction digest:", result.digest);
    } catch (error) {
        handleError(error);
    }
}

main();