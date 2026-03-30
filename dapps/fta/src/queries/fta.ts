import {
    // Core fetch functions
    executeGraphQLQuery, // Raw GraphQL execution
} from "@evefrontier/dapp-kit";
import { GetJumpPermitResponse, GetJumpQuoteResponse, JumpPermit, JumpQuote } from "./types";
import { GET_OBJECT_JSON_BY_ID } from "./queries";

export async function getJumpQuote(id: string): Promise<JumpQuote> {
    const result = await executeGraphQLQuery<GetJumpQuoteResponse>(
        GET_OBJECT_JSON_BY_ID,
        {
            address: id,
        },
    );

    const quote = result.data?.object.asMoveObject?.contents.json;
    if (!quote) {
        throw new Error('Jump quote not found');
    }

    quote.estimate.prepared_at = Number(quote.estimate.prepared_at);
    quote.estimate.source_gate_fee = Number(quote.estimate.source_gate_fee);
    quote.estimate.destination_gate_fee = Number(quote.estimate.destination_gate_fee);
    quote.estimate.source_network_node_fee = Number(quote.estimate.source_network_node_fee);
    quote.estimate.destination_network_node_fee = Number(quote.estimate.destination_network_node_fee);
    quote.estimate.scaling_factor = Number(quote.estimate.scaling_factor);
    quote.estimate.penalty_factor = Number(quote.estimate.penalty_factor);
    quote.estimate.bounty_fee = Number(quote.estimate.bounty_fee);
    quote.estimate.developer_fee = Number(quote.estimate.developer_fee);
    quote.estimate.validity_duration = Number(quote.estimate.validity_duration);
    quote.estimate.precision_factor = Number(quote.estimate.precision_factor);

    return quote;
}

export async function getJumpPermit(id: string): Promise<JumpPermit> {
    const result = await executeGraphQLQuery<GetJumpPermitResponse>(
        GET_OBJECT_JSON_BY_ID,
        {
            address: id,
        },
    );

    const permit = result.data?.object.asMoveObject?.contents.json;
    if (!permit) {
        throw new Error('Jump permit not found');
    }

    permit.expires_at_timestamp_ms = Number(permit.expires_at_timestamp_ms);

    return permit;
}