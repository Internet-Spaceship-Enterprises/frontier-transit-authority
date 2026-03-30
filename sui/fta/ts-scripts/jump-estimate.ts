import "dotenv/config";
import { Transaction } from "@mysten/sui/transactions";
import { FTA_PACKAGE_ID, FTA_OBJECT_ID } from "./config";
import {
    getEnvConfig,
    handleError,
    hydrateWorldConfig,
    initializeContext,
    requireEnv,
} from "../../../ts-scripts/utils/helper";
import { deriveObjectId } from "../../../ts-scripts/utils/derive-object-id";
import { GAME_CHARACTER_ID, GATE_ITEM_ID_1, GATE_ITEM_ID_2 } from "../../../ts-scripts/utils/constants"; import { bcs } from '@mysten/sui/bcs';

const JumpEstimate = bcs.struct('JumpEstimate', {
    id: bcs.Address,
    prepared_at: bcs.U64,
    character_id: bcs.Address,
    source_gate_id: bcs.Address,
    destination_gate_id: bcs.Address,
    source_gate_fee: bcs.U64,
    destination_gate_fee: bcs.U64,
    source_network_node_fee: bcs.U64,
    destination_network_node_fee: bcs.U64,
    scaling_factor: bcs.U64,
    penalty_factor: bcs.U64,
    bounty_fee: bcs.U64,
    developer_fee: bcs.U64,
    validity_duration: bcs.U64,
    precision_factor: bcs.U64,
});

type JumpEstimate = typeof JumpEstimate.$inferType;

export async function getJumpEstimate(
    ctx: ReturnType<typeof initializeContext>,
    characterId: number,
    gateItemId1: bigint,
    gateItemId2: bigint,
) {
    const { client, keypair, config, address } = ctx;
    let tx = new Transaction();
    tx.setSender(address);

    const characterObjectId = deriveObjectId(config.objectRegistry, characterId, config.packageId);
    const gate1Id = deriveObjectId(config.objectRegistry, gateItemId1, config.packageId);
    const gate2Id = deriveObjectId(config.objectRegistry, gateItemId2, config.packageId);

    tx.moveCall({
        target: `${FTA_PACKAGE_ID}::fta::jump_estimate`,
        arguments: [
            tx.object(FTA_OBJECT_ID),
            tx.object(characterObjectId),
            tx.object(gate1Id),
            tx.object(gate2Id),
            tx.pure.u64(1),
            tx.object.clock(),
        ],
    });

    const txBytes = await tx.build({ client });
    const sim = await client.core.simulateTransaction({
        transaction: txBytes,
        include: {
            effects: true,
            commandResults: true,
        },
    });

    const estimate = JumpEstimate.parse(sim.commandResults?.[0].returnValues?.[0].bcs);

    console.log("Jump Estimate:", estimate);
}

async function main() {
    try {
        const env = getEnvConfig();
        const playerKey = requireEnv("PLAYER_B_PRIVATE_KEY");
        const playerCtx = initializeContext(env.network, playerKey);
        await hydrateWorldConfig(playerCtx);
        await getJumpEstimate(playerCtx, GAME_CHARACTER_ID, GATE_ITEM_ID_1, GATE_ITEM_ID_2);

    } catch (error) {
        handleError(error);
    }
}

main();