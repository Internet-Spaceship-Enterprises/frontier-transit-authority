import "dotenv/config";
import { Transaction } from "@mysten/sui/transactions";
import { MODULES } from "../utils/config";
import {
    getEnvConfig,
    handleError,
    hydrateWorldConfig,
    initializeContext,
    requireEnv,
} from "../utils/helper";
import { delay, getDelayMs } from "../utils/delay";
import { deriveObjectId } from "../utils/derive-object-id";
import { getOwnerCap as gateGetOwnerCap } from "../gate/helper";
import { getOwnerCap as networkNodeGetOwnerCap } from "../network-node/helper";
import { GAME_CHARACTER_ID, GATE_ITEM_ID_1, GATE_ITEM_ID_2, NWN_ITEM_ID } from "../utils/constants";

const packageId = "0x591fe414ccc58ff0f2ef3596547ebd2ddf02f1f76ac1f8270b08ea25428bc702";
const fgnId = "0x49cc54d6e1ae739f9e8da1f7cf828c6d34ebec234bc6d4663e18f372ab8dbefd";

async function onlineGate(
    ctx: ReturnType<typeof initializeContext>,
    characterId: number,
    nwnId: bigint,
    gateItemId: bigint
) {
    const { client, keypair, config, address } = ctx;

    const characterObjectId = deriveObjectId(config.objectRegistry, characterId, config.packageId);
    const networkNodeObjectId = deriveObjectId(config.objectRegistry, nwnId, config.packageId);
    const gateId = deriveObjectId(config.objectRegistry, gateItemId, config.packageId);

    const gateOwnerCapId = await gateGetOwnerCap(gateId, client, config, address);
    if (!gateOwnerCapId) {
        throw new Error("Gate OwnerCap not found (make sure the character owns the gate)");
    }
    const nnOwnerCapId = await networkNodeGetOwnerCap(networkNodeObjectId, client, config, address);
    if (!nnOwnerCapId) {
        throw new Error("Network Node OwnerCap not found (make sure the character owns the network node)");
    }

    const tx = new Transaction();

    // const [online] = tx.moveCall({
    //     target: `${config.packageId}::${MODULES.GATE}::is_online`,
    //     arguments: [
    //         tx.object(gateId),
    //     ],
    // });

    console.log(characterObjectId);
    let args = [
        tx.object(fgnId),
        tx.object(characterObjectId),
        tx.object(gateId),
        //tx.object(gateOwnerCapId),
        tx.object(networkNodeObjectId),
        tx.object(nnOwnerCapId),
        tx.pure.u64(99),
        tx.object(config.energyConfig),
        tx.object("0x6"),
    ];

    // const [count] = tx.moveCall({
    //     target: `${packageId}::fgn::transfer_gate`,
    //     arguments: ,
    // });

    // const [gateOwnerCap, receipt] = tx.moveCall({
    //     target: `${config.packageId}::${MODULES.CHARACTER}::borrow_owner_cap`,
    //     typeArguments: [`${config.packageId}::${MODULES.GATE}::Gate`],
    //     arguments: [tx.object(characterObjectId), tx.object(gateOwnerCapId)],
    // });

    // tx.moveCall({
    //     target: `${config.packageId}::${MODULES.GATE}::online`,
    //     arguments: [
    //         tx.object(gateId),
    //         tx.object(networkNodeObjectId),
    //         tx.object(config.energyConfig),
    //         gateOwnerCap,
    //     ],
    // });

    // tx.moveCall({
    //     target: `${config.packageId}::${MODULES.CHARACTER}::return_owner_cap`,
    //     typeArguments: [`${config.packageId}::${MODULES.GATE}::Gate`],
    //     arguments: [tx.object(characterObjectId), gateOwnerCap, receipt],
    // });

    const result = await client.signAndExecuteTransaction({
        transaction: tx,
        signer: keypair,
        options: { showObjectChanges: true, showEffects: true, showEvents: true },
    });

    const res = await client.devInspectTransactionBlock({
        sender: address,
        transactionBlock: tx,
    });

    const raw = res.results?.[0]?.returnValues?.[0];
    if (!raw) {
        throw new Error("No return value");
    }
    console.log("Count: ", raw);

    console.log("\nGate transferred successfully!");
    console.log("Transaction digest:", result.digest);
}

async function main() {
    try {
        const env = getEnvConfig();

        const playerKey = requireEnv("PLAYER_A_PRIVATE_KEY");
        const playerCtx = initializeContext(env.network, playerKey);
        await hydrateWorldConfig(playerCtx);

        await onlineGate(playerCtx, GAME_CHARACTER_ID, NWN_ITEM_ID, GATE_ITEM_ID_1);
        await delay(getDelayMs());
        await onlineGate(playerCtx, GAME_CHARACTER_ID, NWN_ITEM_ID, GATE_ITEM_ID_2);
    } catch (error) {
        handleError(error);
    }
}

main();