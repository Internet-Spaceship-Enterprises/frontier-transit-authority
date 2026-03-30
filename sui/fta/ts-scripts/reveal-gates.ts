import "dotenv/config";
import { Transaction } from "@mysten/sui/transactions";
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
import { executeSponsoredTransaction } from "../../../ts-scripts/utils/transaction";
import { keypairFromPrivateKey } from "../../../ts-scripts/utils/client";

async function revealGate(
    ctx: ReturnType<typeof initializeContext>,
    gateItemId: bigint,
    playerAddress: string,
    adminAddress: string,
    adminKeypair: ReturnType<typeof keypairFromPrivateKey>
) {
    const { client, keypair: playerKeypair, config } = ctx;
    let tx = new Transaction();

    const gateId = deriveObjectId(config.objectRegistry, gateItemId, config.packageId);

    tx.setSender(playerAddress);
    tx.setGasOwner(adminAddress);

    tx.moveCall({
        target: `${config.packageId}::${MODULES.GATE}::reveal_location`,
        arguments: [
            tx.object(gateId),
            tx.object(config.locationRegistry),
            tx.object(config.adminAcl),
            tx.pure.u64(999),
            tx.pure.string("x-coord"),
            tx.pure.string("y-coord"),
            tx.pure.string("z-coord"),
        ],
    });

    const result = await executeSponsoredTransaction(
        tx,
        client,
        playerKeypair,
        adminKeypair,
        playerAddress,
        adminAddress,
        { showObjectChanges: true, showEffects: true, showEvents: true },
    );

    console.log("\nGate successfully revealed!");
    console.log("Transaction digest:", result.digest);
}

async function main() {
    try {
        const env = getEnvConfig();

        const playerKey = requireEnv("PLAYER_B_PRIVATE_KEY");
        const playerCtx = initializeContext(env.network, playerKey);
        await hydrateWorldConfig(playerCtx);
        const adminKeypair = keypairFromPrivateKey(env.adminExportedKey);
        const adminAddress = adminKeypair.getPublicKey().toSuiAddress();
        const playerAddress = playerCtx.address;
        await revealGate(playerCtx, GATE_ITEM_ID_1, playerAddress, adminAddress, adminKeypair);
        await delay(getDelayMs());
        await revealGate(playerCtx, GATE_ITEM_ID_2, playerAddress, adminAddress, adminKeypair);

    } catch (error) {
        handleError(error);
    }
}

main();