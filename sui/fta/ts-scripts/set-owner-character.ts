import "dotenv/config";
import { Transaction } from "@mysten/sui/transactions";
import { FTA_PACKAGE_ID, FTA_OBJECT_ID, FTA_DEV_CAP_ID } from "./config";
import {
    getEnvConfig,
    handleError,
    hydrateWorldConfig,
    initializeContext,
    requireEnv,
} from "../../../ts-scripts/utils/helper";
import { deriveObjectId } from "../../../ts-scripts/utils/derive-object-id";
import { GAME_CHARACTER_B_ID } from "../../../ts-scripts/utils/constants";

async function setOwnerCharacter(
    ctx: ReturnType<typeof initializeContext>,
    characterId: number,
) {
    const { client, keypair, config, address } = ctx;
    let tx = new Transaction();

    const characterObjectId = deriveObjectId(config.objectRegistry, characterId, config.packageId);

    tx.moveCall({
        target: `${FTA_PACKAGE_ID}::fta::set_owner_character`,
        arguments: [
            tx.object(FTA_OBJECT_ID),
            tx.object(FTA_DEV_CAP_ID),
            tx.object(characterObjectId),
        ],
    });

    const result = await client.signAndExecuteTransaction({
        transaction: tx,
        signer: keypair,
        options: { showObjectChanges: true, showEffects: true, showEvents: true },
    });

    console.log("\nFTA Owner Character successfully set!");
    console.log("Transaction digest:", result.digest);
}

async function main() {
    try {
        const env = getEnvConfig();

        const playerKey = requireEnv("PLAYER_B_PRIVATE_KEY");
        const playerCtx = initializeContext(env.network, playerKey);
        await hydrateWorldConfig(playerCtx);

        await setOwnerCharacter(playerCtx, GAME_CHARACTER_B_ID);
    } catch (error) {
        handleError(error);
    }
}

main();