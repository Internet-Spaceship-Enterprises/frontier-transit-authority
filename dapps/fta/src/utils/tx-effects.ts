import { DAppKit, ClientWithCoreApi } from "@mysten/dapp-kit-react";
import { useDAppKit } from "@mysten/dapp-kit-react";

type TransactionResultWithEffects = Awaited<ReturnType<ReturnType<typeof useDAppKit>["signAndExecuteTransaction"]>>;

export async function getTxEffects(
    dAppKit: DAppKit<[], ClientWithCoreApi>,
    txResult: TransactionResultWithEffects,
) {
    const finalResult = await dAppKit.getClient().core.waitForTransaction({
        result: txResult,
        include: {
            objectTypes: true,
            effects: true,
        },
    });
    return finalResult;
}

export function getObjectIdsFromEffects(
    effects: Awaited<ReturnType<typeof getTxEffects>>,
    idOperation?: 'Created' | 'Mutated' | 'Deleted' | 'Unwrapped' | 'Wrapped',
    objectTypeSuffix?: string,
    objectTypePrefix?: string,
): string[] {
    if (!effects.Transaction) {
        throw new Error('Transaction result does not contain transaction data.');
    }

    let objects = effects.Transaction.effects.changedObjects;
    if (idOperation) {
        objects = objects.filter(change => change.idOperation === idOperation);
    }
    if (objectTypeSuffix) {
        objects = objects.filter(change => effects.Transaction?.objectTypes[change.objectId]?.endsWith(objectTypeSuffix));
    }
    if (objectTypePrefix) {
        objects = objects.filter(change => effects.Transaction?.objectTypes[change.objectId]?.startsWith(objectTypePrefix));
    }
    return objects.map(change => change.objectId);
}