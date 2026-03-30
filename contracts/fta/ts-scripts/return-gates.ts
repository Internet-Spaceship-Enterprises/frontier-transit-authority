import "dotenv/config";
import { Transaction } from "@mysten/sui/transactions";
import { FTA_PACKAGE_ID, FTA_OBJECT_ID, FTA_NEW_UPGRADE_CAP_ID } from "./config";
import { MODULES } from "../../../ts-scripts/utils/config";
import {
    getEnvConfig,
    handleError,
    hydrateWorldConfig,
    initializeContext,
    requireEnv,
} from "../../../ts-scripts/utils/helper";
import { deriveObjectId } from "../../../ts-scripts/utils/derive-object-id";
import { getGateOwnerCapId } from "./utils";
import { delay, getDelayMs } from "../../../ts-scripts/utils/delay";
import { GAME_CHARACTER_B_ID, GATE_ITEM_ID_1, GATE_ITEM_ID_2 } from "../../../ts-scripts/utils/constants";

async function returnGateToOwner(
    ctx: ReturnType<typeof initializeContext>,
    gateItemId: bigint,
) {
    const { client, keypair, config, address } = ctx;
    let tx = new Transaction();

    const gateId = deriveObjectId(config.objectRegistry, gateItemId, config.packageId);
    const gateOwnerCapId = await getGateOwnerCapId(gateId, client, config, address);
    if (!gateOwnerCapId) {
        throw new Error("Gate 1 OwnerCap not found (make sure the character owns the gate)");
    }

    console.log(`Returning gate: ${gateId}`);
    tx.moveCall({
        target: `${FTA_PACKAGE_ID}::fta::deregister_gate`,
        arguments: [
            tx.object(FTA_OBJECT_ID),
            tx.object(FTA_NEW_UPGRADE_CAP_ID),
            tx.object(gateId),
            tx.object(gateOwnerCapId),
        ],
    });

    const result = await client.signAndExecuteTransaction({
        transaction: tx,
        signer: keypair,
        options: { showObjectChanges: true, showEffects: true, showEvents: true },
    });

    console.log("\nGate successfully returned to owner!");
    console.log("Transaction digest:", result.digest);
}

async function main() {
    try {
        const env = getEnvConfig();

        const playerKey = requireEnv("PLAYER_B_PRIVATE_KEY");
        const playerCtx = initializeContext(env.network, playerKey);
        await hydrateWorldConfig(playerCtx);

        await returnGateToOwner(playerCtx, GATE_ITEM_ID_1);
        await delay(getDelayMs());
        await returnGateToOwner(playerCtx, GATE_ITEM_ID_2);
    } catch (error) {
        handleError(error);
    }
}

main();