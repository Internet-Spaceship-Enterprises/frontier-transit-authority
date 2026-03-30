import "dotenv/config";
import { Transaction } from "@mysten/sui/transactions";
import { MODULES } from "../../../ts-scripts/utils/config";
import { FTA_PACKAGE_ID, FTA_OBJECT_ID } from "./config";
import {
    getEnvConfig,
    handleError,
    hydrateWorldConfig,
    initializeContext,
    requireEnv,
} from "../../../ts-scripts/utils/helper";
import { deriveObjectId } from "../../../ts-scripts/utils/derive-object-id";
import { getGateOwnerCapId, getNetworkNodeOwnerCapId, getEnergySourceId, gateNetworkNodeRegistered } from "./utils";
import { GAME_CHARACTER_ID, GATE_ITEM_ID_1, GATE_ITEM_ID_2 } from "../../../ts-scripts/utils/constants";

async function prepareTransferGate(
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

    const gate1OwnerCapId = await getGateOwnerCapId(gate1Id, client, config, address);
    if (!gate1OwnerCapId) {
        throw new Error("Gate 1 OwnerCap not found (make sure the character owns the gate)");
    }
    const gate2OwnerCapId = await getGateOwnerCapId(gate2Id, client, config, address);
    if (!gate2OwnerCapId) {
        throw new Error("Gate 2 OwnerCap not found (make sure the character owns the gate)");
    }
    const [gate1OwnerCap, gate1OwnerReceipt] = tx.moveCall({
        target: `${config.packageId}::${MODULES.CHARACTER}::borrow_owner_cap`,
        typeArguments: [`${config.packageId}::${MODULES.GATE}::Gate`],
        arguments: [tx.object(characterObjectId), tx.object(gate1OwnerCapId)],
    });
    const [gate2OwnerCap, gate2OwnerReceipt] = tx.moveCall({
        target: `${config.packageId}::${MODULES.CHARACTER}::borrow_owner_cap`,
        typeArguments: [`${config.packageId}::${MODULES.GATE}::Gate`],
        arguments: [tx.object(characterObjectId), tx.object(gate2OwnerCapId)],
    });

    const gate1NetworkNodeId = await getEnergySourceId(gate1Id, client, config, address);
    if (!gate1NetworkNodeId) {
        throw new Error("Cannot transfer gate 1 without a network node connected");
    }

    const gate2NetworkNodeId = await getEnergySourceId(gate2Id, client, config, address);
    if (!gate2NetworkNodeId) {
        throw new Error("Cannot transfer gate 2 without a network node connected");
    }

    let nn1OwnerCap = null;
    let nn1OwnerReceipt = null;
    if (! await gateNetworkNodeRegistered(gate1Id, client, address)) {
        const nn1OwnerCapId = await getNetworkNodeOwnerCapId(gate1NetworkNodeId, client, config, address);
        if (!nn1OwnerCapId) {
            throw "Unable to load gate 1's Network Node Owner Cap ID";
        }
        [nn1OwnerCap, nn1OwnerReceipt] = tx.moveCall({
            target: `${config.packageId}::${MODULES.CHARACTER}::borrow_owner_cap`,
            typeArguments: [`${config.packageId}::${MODULES.NETWORK_NODE}::NetworkNode`],
            arguments: [tx.object(characterObjectId), tx.object(nn1OwnerCapId)],
        });
    }

    if (gate1NetworkNodeId == gate2NetworkNodeId) {
        tx.moveCall({
            target: `${FTA_PACKAGE_ID}::transfer::transfer_gate_pair_same_network_node`,
            arguments: [
                tx.object(FTA_OBJECT_ID),
                tx.object(characterObjectId),
                tx.object(gate1Id),
                gate1OwnerCap,
                gate1OwnerReceipt,
                tx.object(gate1NetworkNodeId),
                tx.object.option({
                    type: `${config.packageId}::${MODULES.ACCESS}::OwnerCap<${config.packageId}::${MODULES.NETWORK_NODE}::NetworkNode>`,
                    value: nn1OwnerCap,
                }),
                tx.object.option({
                    type: `${config.packageId}::${MODULES.ACCESS}::ReturnOwnerCapReceipt`,
                    value: nn1OwnerReceipt,
                }),
                tx.pure.u64(99),
                tx.object(gate2Id),
                gate2OwnerCap,
                gate2OwnerReceipt,
                tx.pure.u64(99),
                tx.object(config.energyConfig),
                tx.object(config.locationRegistry),
                tx.object.clock(),
            ],
        });
    } else {
        let nn2OwnerCap = null;
        let nn2OwnerReceipt = null;
        if (! await gateNetworkNodeRegistered(gate2Id, client, address)) {
            const nn2OwnerCapId = await getNetworkNodeOwnerCapId(gate2NetworkNodeId, client, config, address);
            if (!nn2OwnerCapId) {
                throw "Unable to load gate 2's Network Node Owner Cap ID";
            }
            [nn2OwnerCap, nn2OwnerReceipt] = tx.moveCall({
                target: `${config.packageId}::${MODULES.CHARACTER}::borrow_owner_cap`,
                typeArguments: [`${config.packageId}::${MODULES.NETWORK_NODE}::NetworkNode`],
                arguments: [tx.object(characterObjectId), tx.object(nn2OwnerCapId)],
            });
        }

        tx.moveCall({
            target: `${FTA_PACKAGE_ID}::transfer::transfer_gate_pair`,
            arguments: [
                tx.object(FTA_OBJECT_ID),
                tx.object(characterObjectId),
                tx.object(gate1Id),
                gate1OwnerCap,
                gate1OwnerReceipt,
                tx.object(gate1NetworkNodeId),
                tx.object.option({
                    type: `${config.packageId}::${MODULES.ACCESS}::OwnerCap<${config.packageId}::${MODULES.NETWORK_NODE}::NetworkNode>`,
                    value: nn1OwnerCap,
                }),
                tx.object.option({
                    type: `${config.packageId}::${MODULES.ACCESS}::ReturnOwnerCapReceipt`,
                    value: nn1OwnerReceipt,
                }),
                tx.pure.u64(99),
                tx.object(gate2Id),
                gate2OwnerCap,
                gate2OwnerReceipt,
                tx.object(gate2NetworkNodeId),
                tx.object.option({
                    type: `${config.packageId}::${MODULES.ACCESS}::OwnerCap<${config.packageId}::${MODULES.NETWORK_NODE}::NetworkNode>`,
                    value: nn2OwnerCap,
                }),
                tx.object.option({
                    type: `${config.packageId}::${MODULES.ACCESS}::ReturnOwnerCapReceipt`,
                    value: nn2OwnerReceipt,
                }),
                tx.pure.u64(99),
                tx.object(config.energyConfig),
                tx.object(config.locationRegistry),
                tx.object.clock(),
            ],
        });
    }

    // Confirm the gates are now managed
    tx.moveCall({
        target: `${FTA_PACKAGE_ID}::fta::assert_gate_managed`,
        arguments: [
            tx.object(FTA_OBJECT_ID),
            tx.object(gate1Id),
        ],
    });
    tx.moveCall({
        target: `${FTA_PACKAGE_ID}::fta::assert_gate_managed`,
        arguments: [
            tx.object(FTA_OBJECT_ID),
            tx.object(gate2Id),
        ],
    });
    console.log(`Transferred gates: \n\t${gate1Id}\n\t${gate2Id}`);

    const result = await client.signAndExecuteTransaction({
        transaction: tx,
        signer: keypair,
        options: { showObjectChanges: true, showEffects: true, showEvents: true },
    });

    console.log("\nGates transferred successfully!");
    console.log("Transaction digest:", result.digest);

}

async function main() {
    try {
        const env = getEnvConfig();

        const playerKey = requireEnv("PLAYER_A_PRIVATE_KEY");
        const playerCtx = initializeContext(env.network, playerKey);
        await hydrateWorldConfig(playerCtx);

        await prepareTransferGate(playerCtx, GAME_CHARACTER_ID, GATE_ITEM_ID_1, GATE_ITEM_ID_2);
    } catch (error) {
        handleError(error);
    }
}

main();
