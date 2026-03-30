import { getEveWorldPackageId } from "@evefrontier/dapp-kit";
import { DAppKit, ClientWithCoreApi } from "@mysten/dapp-kit-react";
import { Transaction } from "@mysten/sui/transactions";
import { fetchAssemblyInfo, } from "../queries";

export async function registerNetworkNode(dAppKit: DAppKit<[], ClientWithCoreApi>, ftaPackageId: string, networkNodeId: string, characterObjectId: string, fee: bigint, fee_recipient_address: string) {

    const info = await fetchAssemblyInfo(networkNodeId);
    if (info?.assembly) {
        console.log("Assembly info:", info);
    } else {
        console.error("Failed to fetch assembly info");
        return;
    }
    const tx = new Transaction();

    const [nnOwnerCap, nnOwnerReceipt] = tx.moveCall({
        target: `${getEveWorldPackageId()}::character::borrow_owner_cap`,
        typeArguments: [`${getEveWorldPackageId()}::network_node::NetworkNode`],
        arguments: [tx.object(characterObjectId), tx.object(info.assembly.id)],
    });

    tx.moveCall({
        target: `${ftaPackageId}::registration::register_network_node`,
        arguments: [
            tx.object(ftaPackageId),
            tx.object(characterObjectId),
            tx.object(networkNodeId),
            nnOwnerCap,
            tx.pure.u64(fee),
            tx.pure.address(fee_recipient_address),
            tx.object.clock(),
        ],
    });

    tx.moveCall({
        target: `${getEveWorldPackageId()}::character::return_owner_cap`,
        typeArguments: [`${getEveWorldPackageId()}::network_node::NetworkNode`],
        arguments: [
            tx.object(characterObjectId),
            nnOwnerCap,
            nnOwnerReceipt,
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