import { DAppKit, ClientWithCoreApi } from "@mysten/dapp-kit-react";
import { Transaction } from "@mysten/sui/transactions";
import { FTA_OBJECT_ID, FTA_PUBLISHED_AT } from "../../libs/constants";
import { getJumpQuote as getJumpQuoteFromGraphQL } from "../graphql/fta";
import { getObjectIdsFromEffects, getTxEffects } from "../utils/tx-effects";
import { sleep } from "../utils/sleep";

export async function getJumpQuote(
    dAppKit: DAppKit<[], ClientWithCoreApi>,
    walletAddress: string,
    characterObjectId: string,
    source_gate_id: string,
    destination_gate_id: string,
) {
    const tx = new Transaction();

    const quoteTx = tx.moveCall({
        target: `${FTA_PUBLISHED_AT}::fta::jump_quote`,
        arguments: [
            tx.object(FTA_OBJECT_ID),
            tx.object(characterObjectId),
            tx.object(source_gate_id),
            tx.object(destination_gate_id),
            tx.pure.u64(0),
            tx.object.clock(),
        ],
    });
    tx.transferObjects([quoteTx], walletAddress);

    try {
        const result = await dAppKit.signAndExecuteTransaction({
            transaction: tx,
        });

        if (result.FailedTransaction) {
            throw new Error(`Transaction failed: ${result.FailedTransaction.status.error?.message}`);
        }

        const effects = await getTxEffects(dAppKit, result);
        const quoteObjectIds = getObjectIdsFromEffects(effects, 'Created', '::jump_quote::JumpQuote');

        if (quoteObjectIds.length === 0) {
            throw new Error('No jump quote object found in transaction effects');
        }

        const quoteObjectId = quoteObjectIds[0];

        let quote = null;
        while (!quote) {
            try {
                quote = await getJumpQuoteFromGraphQL(quoteObjectId);
            } catch (error) {
                console.debug('Jump quote not found yet, retrying in 500 milliseconds...');
                await sleep(500);
            }
        }

        return quote;
    } catch (error) {
        throw new Error(`Transaction failed: ${error}`);
    }
}
