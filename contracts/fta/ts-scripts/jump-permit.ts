import "dotenv/config";
import { bcs } from "@mysten/sui/bcs";
import { Transaction, coinWithBalance } from "@mysten/sui/transactions";
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
import { getGateOwnerCapId, getNetworkNodeOwnerCapId, getEnergySourceId, gateNetworkNodeRegistered } from "./utils";
import { delay, getDelayMs } from "../../../ts-scripts/utils/delay";


export async function getJumpQuote(
    ctx: ReturnType<typeof initializeContext>,
    characterId: number,
    gateItemId1: bigint,
    gateItemId2: bigint,
) {
    const { client, keypair, config, address } = ctx;

    const characterObjectId = deriveObjectId(config.objectRegistry, characterId, config.packageId);
    const gate1Id = deriveObjectId(config.objectRegistry, gateItemId1, config.packageId);
    const gate2Id = deriveObjectId(config.objectRegistry, gateItemId2, config.packageId);

    let quoteTx = new Transaction();
    const quote = quoteTx.moveCall({
        target: `${FTA_PACKAGE_ID}::fta::jump_quote`,
        arguments: [
            quoteTx.object(FTA_OBJECT_ID),
            quoteTx.object(characterObjectId),
            quoteTx.object(gate1Id),
            quoteTx.object(gate2Id),
            quoteTx.pure.u64(0),
            quoteTx.object.clock(),
        ],
    });
    quoteTx.transferObjects([quote], address);

    const quoteResult = await client.signAndExecuteTransaction({
        transaction: quoteTx,
        signer: keypair,
        options: { showObjectChanges: true, showEffects: true, showEvents: true },
    });

    const createdQuoteChange = quoteResult.objectChanges?.findLast(change => {
        return change.type === 'created' && change.objectType.endsWith('::jump_quote::JumpQuote')
    });
    if (!createdQuoteChange || createdQuoteChange.type !== 'created') {
        throw new Error('No JumpQuote created in transaction');
    }
    const newQuoteId = createdQuoteChange!.objectId;
    console.log("Quote created with ID: ", newQuoteId);

    await delay(getDelayMs());

    let feeTx = new Transaction();
    feeTx.setSender(address);
    const jumpEstimate = feeTx.moveCall({
        target: `${FTA_PACKAGE_ID}::jump_quote::estimate`,
        arguments: [
            feeTx.object(newQuoteId),
        ],
    });
    feeTx.moveCall({
        target: `${FTA_PACKAGE_ID}::jump_estimate::total_fee`,
        arguments: [
            jumpEstimate,
        ],
    });
    const txBytes = await feeTx.build({ client });
    const feeSim = await client.core.simulateTransaction({
        transaction: txBytes,
        include: {
            effects: true,
            commandResults: true,
        },
    });
    const totalFee = BigInt(bcs.U64.parse(feeSim.commandResults?.[1].returnValues?.[0].bcs));
    console.log("Total fee for the jump quote: ", totalFee);

    const gate1OwnerCapId = await getGateOwnerCapId(gate1Id, client, config, address);
    if (!gate1OwnerCapId) {
        throw new Error("Gate 1 OwnerCap not found (make sure the character owns the gate)");
    }
    const gate2OwnerCapId = await getGateOwnerCapId(gate2Id, client, config, address);
    if (!gate2OwnerCapId) {
        throw new Error("Gate 2 OwnerCap not found (make sure the character owns the gate)");
    }
    const gate1NetworkNodeId = await getEnergySourceId(gate1Id, client, config, address);
    if (!gate1NetworkNodeId) {
        throw new Error("Cannot transfer gate 1 without a network node connected");
    }
    const gate2NetworkNodeId = await getEnergySourceId(gate2Id, client, config, address);
    if (!gate2NetworkNodeId) {
        throw new Error("Cannot transfer gate 2 without a network node connected");
    }

    console.log("Eve coin object ID:", process.env.EVE_COIN_OBJECT_ID);
    console.log("FTA object ID: ", FTA_OBJECT_ID);
    console.log("Character object ID: ", characterObjectId);
    console.log("Quote ID: ", newQuoteId);
    console.log("Gate 1 ID: ", gate1Id);
    console.log("Gate 1 Owner Cap ID: ", gate1OwnerCapId);
    console.log("Gate 1 Network Node ID: ", gate1NetworkNodeId);
    console.log("Gate 2 ID: ", gate2Id);
    console.log("Gate 2 Owner Cap ID: ", gate2OwnerCapId);
    console.log("Gate 2 Network Node ID: ", gate2NetworkNodeId);
    console.log("Energy Config ID: ", config.energyConfig);

    const paymentCoin = coinWithBalance({ balance: totalFee, type: '0xb68df9fbe4f1b57f5289b0e147091427b174553de603c49a5d3172ee56996aa6::EVE::EVE' });
    let tx = new Transaction();
    tx.moveCall({
        target: `${FTA_PACKAGE_ID}::fta::jump_permit`,
        arguments: [
            tx.object(FTA_OBJECT_ID),
            tx.object(newQuoteId),
            tx.object(characterObjectId),
            tx.object(gate1Id),
            tx.object(gate1OwnerCapId),
            tx.object(gate1NetworkNodeId),
            tx.object(gate2Id),
            tx.object(gate2OwnerCapId),
            tx.object(gate2NetworkNodeId),
            paymentCoin,
            tx.object(config.energyConfig),
            tx.object.clock(),
        ],
    });

    const result = await client.signAndExecuteTransaction({
        transaction: tx,
        signer: keypair,
        options: { showObjectChanges: true, showEffects: true, showEvents: true },
    });

    console.log("Transaction digest:", result.digest);
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