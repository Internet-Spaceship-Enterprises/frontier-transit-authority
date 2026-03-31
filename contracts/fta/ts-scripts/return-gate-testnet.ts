import "dotenv/config";
import { Transaction } from "@mysten/sui/transactions";
import { FTA_PUBLISHED_AT, FTA_OBJECT_ID, FTA_UPGRADE_CAP_ID } from "../../../dapps/fta/libs/auto-constants";
import { WORLD_PACKAGE_ORIGINAL_ID } from "../../../dapps/fta/libs/constants";
import {
    getEnvConfig,
    handleError,
    hydrateWorldConfig,
    initializeContext,
    requireEnv,
} from "../../../ts-scripts/utils/helper";
import { bcs } from "@mysten/sui/bcs";
import { SuiJsonRpcClient } from "@mysten/sui/jsonRpc";
import { devInspectMoveCallFirstReturnValueBytes } from "../../../ts-scripts/utils/dev-inspect";

// export async function getGateOwnerCapId(
//     gateId: string,
//     client: SuiJsonRpcClient,
//     senderAddress?: string
// ): Promise<string | null> {
//     try {
//         const bytes = await devInspectMoveCallFirstReturnValueBytes(client, {
//             target: `${WORLD_PACKAGE_ORIGINAL_ID}::gate::owner_cap_id`,
//             senderAddress,
//             arguments: (tx) => [tx.object(gateId)],
//         });

//         if (!bytes) {
//             console.warn("Error checking gate owner cap ID");
//             return null;
//         }

//         return bcs.Address.parse(bytes);
//     } catch (error) {
//         console.warn("Failed to get gate owner cap ID:", error instanceof Error ? error.message : error);
//         return null;
//     }
// }

async function returnGateToOwner(
    ctx: ReturnType<typeof initializeContext>,
    gateId: string,
    gateOwnerCapId: string,
) {
    const { client, keypair, config, address } = ctx;
    let tx = new Transaction();

    // const gateOwnerCapId = await getGateOwnerCapId(gateId, client, address);
    // if (!gateOwnerCapId) {
    //     throw new Error("Gate 1 OwnerCap not found (make sure the character owns the gate)");
    // }

    console.log(`Returning gate: ${gateOwnerCapId}`);
    tx.moveCall({
        target: `${FTA_PUBLISHED_AT}::fta::deregister_gate_original_upgrade_cap`,
        arguments: [
            tx.object(FTA_OBJECT_ID),
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

        const playerKey = requireEnv("UTOPIA_PRIVATE_KEY");
        const gateId = requireEnv("GATE_ID");
        const gateOwnerCapId = requireEnv("GATE_OWNER_CAP_ID");
        const playerCtx = initializeContext("testnet_utopia", playerKey);
        await hydrateWorldConfig(playerCtx);

        await returnGateToOwner(playerCtx, gateId, gateOwnerCapId);
    } catch (error) {
        handleError(error);
    }
}

main();