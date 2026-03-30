import { DAppKit, ClientWithCoreApi } from "@mysten/dapp-kit-react";
import { Transaction } from "@mysten/sui/transactions";
import { FTA_OBJECT_ID, FTA_PUBLISHED_AT } from "../../libs/constants";
import { JumpPermit, JumpQuote } from "../queries/types";
import { Assemblies, AssemblyType } from "@evefrontier/dapp-kit";
import { ENERGY_CONFIG, ASSETS_PACKAGE } from "../../libs/constants";
import { coinWithBalance } from "@mysten/sui/transactions";
import { getObjectIdsFromEffects, getTxEffects } from "../utils/tx-effects";
import { sleep } from "../utils/sleep";
import { getJumpPermit as getJumpPermitFromGraphQL } from "../queries/fta";

function totalFee(jumpQuote: JumpQuote): bigint {
    const base_fee = BigInt(jumpQuote.estimate.source_gate_fee) + BigInt(jumpQuote.estimate.source_network_node_fee) + BigInt(jumpQuote.estimate.destination_gate_fee) + BigInt(jumpQuote.estimate.destination_network_node_fee);
    const scaled_base_fee: bigint = base_fee * BigInt(jumpQuote.estimate.scaling_factor) / BigInt(jumpQuote.estimate.precision_factor);
    const total_fee: bigint = (BigInt(scaled_base_fee) + BigInt(jumpQuote.estimate.bounty_fee) + BigInt(jumpQuote.estimate.developer_fee)) * BigInt(jumpQuote.estimate.penalty_factor) / BigInt(100);
    console.log("Total fee: ", total_fee);
    return total_fee;
}

export async function getJumpPermit(
    dAppKit: DAppKit<[], ClientWithCoreApi>,
    jumpQuote: JumpQuote,
    sourceGate: AssemblyType<Assemblies.SmartGate>,
    destinationGate: AssemblyType<Assemblies.SmartGate>,
): Promise<JumpPermit> {
    const tx = new Transaction();

    if (!sourceGate.energySourceId) {
        throw new Error('Source gate is not linked to a network node');
    }
    if (!destinationGate.energySourceId) {
        throw new Error('Destination gate is not linked to a network node');
    }

    console.log("Source gate: ", sourceGate);

    const paymentCoin = coinWithBalance({ balance: totalFee(jumpQuote), type: `${ASSETS_PACKAGE}::EVE::EVE` });
    tx.moveCall({
        target: `${FTA_PUBLISHED_AT}::fta::jump_permit`,
        arguments: [
            tx.object(FTA_OBJECT_ID),
            tx.object(jumpQuote.id),
            tx.object(jumpQuote.estimate.character_id),
            tx.object(jumpQuote.estimate.source_gate_id),
            tx.object(sourceGate._raw!.contents.json!["owner_cap_id"] as string),
            tx.object(sourceGate.energySourceId),
            tx.object(jumpQuote.estimate.destination_gate_id),
            tx.object(destinationGate._raw!.contents.json!["owner_cap_id"] as string),
            tx.object(destinationGate.energySourceId),
            paymentCoin,
            tx.object(ENERGY_CONFIG),
            tx.object.clock(),
        ],
    });

    try {
        const result = await dAppKit.signAndExecuteTransaction({
            transaction: tx,
        });
        if (result.FailedTransaction) {
            throw new Error(`Transaction failed: ${result.FailedTransaction.status.error?.message}`);
        }

        const effects = await getTxEffects(dAppKit, result);
        const permitObjectIds = getObjectIdsFromEffects(effects, 'Created', '::gate::JumpPermit');

        if (permitObjectIds.length === 0) {
            throw new Error('No jump permit object found in transaction effects');
        }

        const permitObjectId = permitObjectIds[0];

        let permit = null;
        while (!permit) {
            try {
                permit = await getJumpPermitFromGraphQL(permitObjectId);
            } catch (error) {
                console.debug('Jump permit not found yet, retrying in 500 milliseconds...');
                await sleep(500);
            }
        }

        console.log("Jump permit: ", permit);
        return permit;
    } catch (error) {
        throw new Error(`Transaction failed: ${error}`);
    }
}
