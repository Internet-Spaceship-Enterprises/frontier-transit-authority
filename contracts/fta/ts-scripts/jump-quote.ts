import "dotenv/config";
import { Transaction } from "@mysten/sui/transactions";
import { FTA_PACKAGE_ID, FTA_OBJECT_ID, FTA_NEW_UPGRADE_CAP_ID } from "./config";
import {
    getEnvConfig,
    handleError,
    hydrateWorldConfig,
    initializeContext,
    requireEnv,
} from "../../../ts-scripts/utils/helper";
import { deriveObjectId } from "../../../ts-scripts/utils/derive-object-id";
import { GAME_CHARACTER_ID, GATE_ITEM_ID_1, GATE_ITEM_ID_2 } from "../../../ts-scripts/utils/constants";


export async function getJumpQuote(
    ctx: ReturnType<typeof initializeContext>,
    characterId: number,
    gateItemId1: bigint,
    gateItemId2: bigint,
) {
    const { client, keypair, config, address } = ctx;
    let tx = new Transaction();

    const characterObjectId = deriveObjectId(config.objectRegistry, characterId, config.packageId);
    const gate1Id = deriveObjectId(config.objectRegistry, gateItemId1, config.packageId);
    const gate2Id = deriveObjectId(config.objectRegistry, gateItemId2, config.packageId);

    const quote = tx.moveCall({
        target: `${FTA_PACKAGE_ID}::fta::jump_quote`,
        arguments: [
            tx.object(FTA_OBJECT_ID),
            tx.object(characterObjectId),
            tx.object(gate1Id),
            tx.object(gate2Id),
            tx.pure.u64(0),
            tx.object.clock(),
        ],
    });
    tx.transferObjects([quote], address);

    const result = await client.signAndExecuteTransaction({
        transaction: tx,
        signer: keypair,
        options: { showObjectChanges: true, showEffects: true, showEvents: true },
    });

    const createdQuoteChange = result.objectChanges?.findLast(change => {
        return change.type === 'created' && change.objectType.endsWith('::jump_quote::JumpQuote')
    });
    if (!createdQuoteChange || createdQuoteChange.type !== 'created') {
        throw new Error('No JumpQuote created in transaction');
    }
    const newQuoteId = createdQuoteChange!.objectId;

    console.log("Transaction digest:", result.digest);
    console.log("New Jump Quote ID:", newQuoteId);
}

async function main() {
    try {
        const env = getEnvConfig();
        const playerKey = requireEnv("PLAYER_B_PRIVATE_KEY");
        const playerCtx = initializeContext(env.network, playerKey);
        await hydrateWorldConfig(playerCtx);
        await getJumpQuote(playerCtx, GAME_CHARACTER_ID, GATE_ITEM_ID_1, GATE_ITEM_ID_2);

    } catch (error) {
        handleError(error);
    }
}

main();