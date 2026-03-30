import { getEveWorldPackageId, AssemblyType, Assemblies } from "@evefrontier/dapp-kit";
import { DAppKit, ClientWithCoreApi } from "@mysten/dapp-kit-react";
import { Transaction } from "@mysten/sui/transactions";
import { FTA_OBJECT_ID, FTA_PUBLISHED_AT, ENERGY_CONFIG, LOCATION_REGISTRY } from "../../libs/constants";

export async function registerGateTx(
    dAppKit: DAppKit<[], ClientWithCoreApi>,
    characterObjectId: string,
    gate1OwnerCapId: string,
    gate1: AssemblyType<Assemblies.SmartGate>,
    fee1: bigint,
    fee1_recipient_address: string,
    gate2OwnerCapId: string,
    gate2: AssemblyType<Assemblies.SmartGate>,
    fee2: bigint,
    fee2_recipient_address: string
) {
    if (!gate1.energySourceId) {
        console.error("Gate 1 does not have an energy source");
        return;
    }
    if (!gate2.energySourceId) {
        console.error("Gate 2 does not have an energy source");
        return;
    }

    const tx = new Transaction();
    const [gate1OwnerCap, gate1OwnerReceipt] = tx.moveCall({
        target: `${getEveWorldPackageId()}::character::borrow_owner_cap`,
        typeArguments: [`${getEveWorldPackageId()}::gate::Gate`],
        arguments: [tx.object(characterObjectId), tx.object(gate1OwnerCapId)],
    });
    const [gate2OwnerCap, gate2OwnerReceipt] = tx.moveCall({
        target: `${getEveWorldPackageId()}::character::borrow_owner_cap`,
        typeArguments: [`${getEveWorldPackageId()}::gate::Gate`],
        arguments: [tx.object(characterObjectId), tx.object(gate2OwnerCapId)],
    });

    if (gate1.energySourceId == gate2.energySourceId) {
        tx.moveCall({
            target: `${FTA_PUBLISHED_AT}::registration::transfer_gate_pair_same_network_node`,
            arguments: [
                tx.object(FTA_OBJECT_ID),
                tx.object(characterObjectId),
                tx.object(gate1.id),
                gate1OwnerCap,
                gate1OwnerReceipt,
                tx.object(gate1.energySourceId),
                tx.pure.u64(fee1),
                tx.pure.address(fee1_recipient_address),
                tx.object(gate2.id),
                gate2OwnerCap,
                gate2OwnerReceipt,
                tx.pure.u64(fee2),
                tx.pure.address(fee2_recipient_address),
                tx.object(ENERGY_CONFIG),
                tx.object(LOCATION_REGISTRY),
                tx.object.clock(),
            ],
        });
    } else {
        tx.moveCall({
            target: `${FTA_PUBLISHED_AT}::registration::transfer_gate_pair`,
            arguments: [
                tx.object(FTA_OBJECT_ID),
                tx.object(characterObjectId),
                tx.object(gate1.id),
                gate1OwnerCap,
                gate1OwnerReceipt,
                tx.object(gate1.energySourceId),
                tx.pure.u64(fee1),
                tx.pure.address(fee1_recipient_address),
                tx.object(gate2.id),
                gate2OwnerCap,
                gate2OwnerReceipt,
                tx.object(gate2.energySourceId),
                tx.pure.u64(fee2),
                tx.pure.address(fee2_recipient_address),
                tx.object(ENERGY_CONFIG),
                tx.object(LOCATION_REGISTRY),
                tx.object.clock(),
            ],
        });
    }

    // Confirm the gates are now managed
    tx.moveCall({
        target: `${FTA_PUBLISHED_AT}::fta::assert_gate_managed`,
        arguments: [
            tx.object(FTA_OBJECT_ID),
            tx.object(gate1.id),
        ],
    });
    tx.moveCall({
        target: `${FTA_PUBLISHED_AT}::fta::assert_gate_managed`,
        arguments: [
            tx.object(FTA_OBJECT_ID),
            tx.object(gate2.id),
        ],
    });
    console.log(`Transferred gates: \n\t${gate1.id}\n\t${gate2.id}`);

    try {
        const result = await dAppKit.signAndExecuteTransaction({ transaction: tx });
        if (result.FailedTransaction) {
            throw new Error(`Transaction failed: ${result.FailedTransaction.status.error?.message}`);
        }
        console.log('Transaction digest:', result.Transaction.digest);
    } catch (error) {
        console.error('Transaction failed:', error);
    }
}
