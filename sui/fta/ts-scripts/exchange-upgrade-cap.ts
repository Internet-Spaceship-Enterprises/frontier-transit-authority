import "dotenv/config";
import { Transaction } from "@mysten/sui/transactions";
import { FTA_PACKAGE_ID, FTA_OBJECT_ID, FTA_ORIGINAL_UPGRADE_CAP_ID } from "./config";
import { bcs } from '@mysten/sui/bcs';
import {
    getEnvConfig,
    handleError,
    hydrateWorldConfig,
    initializeContext,
    requireEnv,
} from "../../../ts-scripts/utils/helper";
import { appendFile } from 'node:fs';

async function exchangeUpgradeCap(
    ctx: ReturnType<typeof initializeContext>,
) {
    const { client, keypair, config } = ctx;
    let tx = new Transaction();

    tx.moveCall({
        target: `${FTA_PACKAGE_ID}::fta::exchange_upgrade_cap`,
        arguments: [
            tx.object(FTA_OBJECT_ID),
            tx.object(FTA_ORIGINAL_UPGRADE_CAP_ID),
        ],
    });

    const result = await client.signAndExecuteTransaction({
        transaction: tx,
        signer: keypair,
        options: { showObjectChanges: true, showEffects: true, showEvents: true },
    });

    const createdCapChange = result.objectChanges?.findLast(change => {
        return change.type === 'created' && change.objectType.endsWith('::upgrade_cap::UpgradeCap')
    });
    if (!createdCapChange) {
        throw new Error('No UpgradeCap created in transaction');
    }
    const newCapId = createdCapChange!.objectId;

    await appendFile('sui/fta/ts-scripts/config.ts', `\nexport const FTA_NEW_UPGRADE_CAP_ID = "${newCapId}";`, (err) => {
        if (err) {
            console.error('Error appending to file:', err);
        }
    });

    console.log("\nUpgrade cap successfully exchanged!");
    console.log("New upgrade cap ID:", newCapId);
    console.log("Transaction digest:", result.digest);
}

async function main() {
    try {
        const env = getEnvConfig();

        const playerKey = requireEnv("PLAYER_B_PRIVATE_KEY");
        const playerCtx = initializeContext(env.network, playerKey);
        await exchangeUpgradeCap(playerCtx);

    } catch (error) {
        handleError(error);
    }
}

main();