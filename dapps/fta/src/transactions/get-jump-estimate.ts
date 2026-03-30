import { getEveWorldPackageId, AssemblyType, Assemblies } from "@evefrontier/dapp-kit";
import { DAppKit, ClientWithCoreApi } from "@mysten/dapp-kit-react";
import { Transaction } from "@mysten/sui/transactions";
import { FTA_OBJECT_ID, FTA_PUBLISHED_AT } from "../../libs/constants";

export async function getJumpQuote(
    dAppKit: DAppKit<[], ClientWithCoreApi>,
    characterObjectId: string,
    gate1: AssemblyType<Assemblies.SmartGate>,
    gate2: AssemblyType<Assemblies.SmartGate>,
) {

    const tx = new Transaction();

    tx.moveCall({
        target: `${FTA_PUBLISHED_AT}::fta::jump_quote`,
        arguments: [
            tx.object(FTA_OBJECT_ID),
            tx.pure.address(characterObjectId),
            tx.object(gate1.id),
            tx.object(gate2.id),
            tx.pure.u64(100),
            tx.object.clock(),
        ],
    });

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
