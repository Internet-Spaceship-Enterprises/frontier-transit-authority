import { createClient } from "./client";

const tmpclient = createClient("testnet");
type GetTxBlockResult = Awaited<ReturnType<typeof tmpclient.getTransactionBlock>>;
export type SuiObjectChange = NonNullable<GetTxBlockResult['objectChanges']>[number];

export function requireObjectChanges(
    objectChanges: SuiObjectChange[] | undefined | null,
): SuiObjectChange[] {
    if (!objectChanges?.length) {
        throw new Error('No objectChanges found on transaction result');
    }
    return objectChanges;
}

export function findCreatedObjectIdByTypeSuffix(
    objectChanges: SuiObjectChange[],
    typeSuffix: string,
): string {
    const matches = objectChanges.filter(
        (change): change is Extract<SuiObjectChange, { type: 'created' }> =>
            change.type === 'created' &&
            typeof change.objectType === 'string' &&
            change.objectType.endsWith(typeSuffix),
    );

    if (matches.length === 0) {
        throw new Error(
            `Could not find a created object with type ending in "${typeSuffix}"`,
        );
    }

    if (matches.length > 1) {
        throw new Error(
            `Found multiple created objects with type ending in "${typeSuffix}"; refine the selector`,
        );
    }

    return matches[0].objectId;
}
