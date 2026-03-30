import "dotenv/config";
import { Transaction } from "@mysten/sui/transactions";
import { bcs } from '@mysten/sui/bcs';
import { MODULES } from "../../../ts-scripts/utils/config";
import { FGN_PACKAGE_ID, FGN_OBJECT_ID } from "./config";
import {
    getEnvConfig,
    handleError,
    hydrateWorldConfig,
    initializeContext,
    requireEnv,
} from "../../../ts-scripts/utils/helper";
import { deriveObjectId } from "../../../ts-scripts/utils/derive-object-id";
import { getGateOwnerCap, getNetworkNodeOwnerCap, getEnergySourceId } from "./utils";
// import { getOwnerCap as networkNodeGetOwnerCap } from "../network-node/helper";
import { GAME_CHARACTER_ID, GATE_ITEM_ID_1, GATE_ITEM_ID_2, NWN_ITEM_ID } from "../../../ts-scripts/utils/constants";

async function transferGate(
    ctx: ReturnType<typeof initializeContext>,
    characterId: number,
    nwnId: bigint,
    gateItemId: bigint
) {
    const { client, keypair, config, address } = ctx;

    const characterObjectId = deriveObjectId(config.objectRegistry, characterId, config.packageId);
    const gateId = deriveObjectId(config.objectRegistry, gateItemId, config.packageId);

    const gateOwnerCapId = await getGateOwnerCap(gateId, client, config, address);
    if (!gateOwnerCapId) {
        throw new Error("Gate OwnerCap not found (make sure the character owns the gate)");
    }

    const energySourceId = await getEnergySourceId(gateId, client, config, address);
    console.log("Energy source: ", energySourceId);

    let nnOwnerCapId = null;
    if (energySourceId != null) {
        nnOwnerCapId = await getNetworkNodeOwnerCap(energySourceId, client, config, address);
        if (!nnOwnerCapId) {
            throw new Error("Network Node OwnerCap not found (make sure the character owns the network node)");
        }
    }

    // const tx = new Transaction();

    // console.log("FGN object ID: ", FGN_OBJECT_ID);
    // console.log("Character object ID: ", characterObjectId);
    // console.log("Gate object ID: ", gateId);
    // console.log("Gate owner cap ID: ", gateOwnerCapId);
    // console.log("Network node object ID: ", nnOwnerCapId);
    // console.log("Network node owner cap object ID: ", nnOwnerCapId);
    // console.log("Energy config object ID: ", config.energyConfig);


    // let nnOwnerCap = null;
    // let nnOwnerReceipt = null
    // if (nnOwnerCapId != null) {
    //     [nnOwnerCap, nnOwnerReceipt] = tx.moveCall({
    //         target: `${config.packageId}::${MODULES.CHARACTER}::borrow_owner_cap`,
    //         typeArguments: [`${config.packageId}::${MODULES.NETWORK_NODE}::NetworkNode`],
    //         arguments: [tx.object(characterObjectId), tx.object(nnOwnerCapId)],
    //     });
    // }

    // tx.moveCall({
    //     target: `${FGN_PACKAGE_ID}::fgn::transfer_gate`,
    //     arguments: [
    //         tx.object(FGN_OBJECT_ID),
    //         tx.object(characterObjectId),
    //         tx.object(gateId),
    //         gateOwnerCap,
    //         gateOwnerReceipt,
    //         tx.object.option({
    //             type: `${config.packageId}::${MODULES.NETWORK_NODE}::NetworkNode`,
    //             value: energySourceId,
    //         }),
    //         tx.object.option({
    //             type: `${config.packageId}::${MODULES.ACCESS}::OwnerCap`,
    //             value: energySourceId,
    //         }),
    //         nnOwnerCap,
    //         nnOwnerReceipt,
    //         tx.pure.u64(99),
    //         tx.object(config.energyConfig),
    //         tx.object("0x6"),
    //     ],
    // });

    // const result = await client.signAndExecuteTransaction({
    //     transaction: tx,
    //     signer: keypair,
    //     options: { showObjectChanges: true, showEffects: true, showEvents: true },
    // });

    // console.log("\nGate transferred successfully!");
    // console.log("Transaction digest:", result.digest);
}

async function main() {
    try {
        const env = getEnvConfig();

        const playerKey = requireEnv("PLAYER_A_PRIVATE_KEY");
        const playerCtx = initializeContext(env.network, playerKey);
        await hydrateWorldConfig(playerCtx);
        console.log(playerCtx);

        await transferGate(playerCtx, GAME_CHARACTER_ID, NWN_ITEM_ID, GATE_ITEM_ID_2);
    } catch (error) {
        handleError(error);
    }
}

main();