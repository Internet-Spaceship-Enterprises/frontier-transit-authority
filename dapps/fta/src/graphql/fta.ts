import {
    executeGraphQLQuery
} from "@evefrontier/dapp-kit";
import { GetJumpPermitResponse, GetJumpQuoteResponse, JumpPermit, JumpQuote } from "./types";
import { GET_FTA, GET_OBJECT_JSON_BY_ID } from "./queries";
import { FTA_OBJECT_ID } from "../../libs/auto-constants";
import { FTASchema, FTAType } from "../types/fta";
import { GateRecordType, GateRecordSchema } from "../types/gate";
import { NetworkNodeRecordType, NetworkNodeRecordSchema } from "../types/network-node";
import { getTableData } from "./tables";
// export interface JumpHistoryEntry {
//     estimate: JumpEstimate,
//     character_id: string,
//     permit_id: string,
// }

// export interface JumpHistory {
//     entries: Record<string, JumpHistoryEntry>,
// }

// export interface FeeHistory {
//     history: {
//         jump_fee: bigint,
//         takes_effect_on: number,
//         submitted_on: number,
//     }[]
// }

interface GetFTAResponse {
    object: {
        asMoveObject: {
            contents: {
                json: {
                    id: string
                    deployer_addr: string
                    upgrade_cap_exchanged: boolean
                    gate_registry: {
                        table: {
                            id: string
                        }
                    }
                    network_node_registry: {
                        table: {
                            id: string
                        }
                    }
                    jump_history: {
                        entries: {
                            id: string
                        }
                        entries_by_character: {
                            id: string
                        }
                    }
                    killmail_registry: {
                        processed_killmails: {
                            id: string
                        }
                    }
                    blacklist: {
                        records: {
                            id: string
                        }
                    }
                    bounty_board: {
                        character_bounties: {
                            id: string
                        }
                        tribe_bounties: {
                            id: string
                        }
                    }
                }
            }
        }
    }
}

export interface DynamicFields<K, V> {
    pageInfo: {
        hasNextPage: boolean;
        endCursor: string;
    }
    nodes: {
        name: {
            json: K;
        }
        value: {
            json: {
                value: V;
            }
        }
    }[]
}

export async function getFTA(): Promise<FTAType> {
    const result = await executeGraphQLQuery<GetFTAResponse>(
        GET_FTA,
        {
            address: FTA_OBJECT_ID,
        },
    );
    if (!result.data) {
        throw new Error("Failed to fetch FTA data");
    }
    const gateRegistryPromise = getTableData<string, GateRecordType>(result.data.object.asMoveObject.contents.json.gate_registry.table.id, GateRecordSchema, true);
    const networkNodeRegistryPromise = getTableData<string, NetworkNodeRecordType>(result.data.object.asMoveObject.contents.json.network_node_registry.table.id, NetworkNodeRecordSchema, true);
    // const jumpHistory = getTableData<string, JumpHistoryEntry>(result.data.object.asMoveObject.contents.json.jump_history.entries.id);
    // const jumpHistoryByCharacter = getTableData<string, JumpHistoryEntry>(result.data.object.asMoveObject.contents.json.jump_history.entries_by_character.id);
    //const killmailRegistry = getTableData<string, GateRecord>(result.data.object.asMoveObject.contents.json.killmail_registry.processed_killmails.id);
    //const blacklist = getTableData<string, GateRecord>(result.data.object.asMoveObject.contents.json.blacklist.records.id);
    //const characterBounties = getTableData<string, GateRecord>(result.data.object.asMoveObject.contents.json.bounty_board.character_bounties.id);
    //const tribeBounties = getTableData<string, GateRecord>(result.data.object.asMoveObject.contents.json.bounty_board.tribe_bounties.id);

    const [
        gateRegistry,
        networkNodeRegistry,
        // jumpHistoryData,
        // jumpHistoryByCharacterData,
        // killmailRegistryData, 
        // blacklistData, 
        // characterBountiesData, 
        // tribeBountiesData
    ] = await Promise.all([
        gateRegistryPromise,
        networkNodeRegistryPromise,
        // jumpHistory,
        // jumpHistoryByCharacter,
        // killmailRegistry,
        // blacklist,
        // characterBounties,
        // tribeBounties,
    ]);

    return FTASchema.parse({
        id: result.data.object.asMoveObject.contents.json.id,
        deployer_addr: result.data.object.asMoveObject.contents.json.deployer_addr,
        upgrade_cap_exchanged: result.data.object.asMoveObject.contents.json.upgrade_cap_exchanged,
        gate_registry: gateRegistry,
        network_node_registry: networkNodeRegistry,
        // jump_history: jumpHistoryData,
        // jump_history_by_character: jumpHistoryByCharacterData,
        // killmail_registry: killmailRegistryData,  
        // blacklist: blacklistData,
        // character_bounties: characterBountiesData,
        // tribe_bounties: tribeBountiesData,
    });

    // const fta: FTA = {
    //     id: result.data.object.asMoveObject.contents.json.id,
    //     deployer_addr: result.data.object.asMoveObject.contents.json.deployer_addr,
    //     upgrade_cap_exchanged: result.data.object.asMoveObject.contents.json.upgrade_cap_exchanged,
    //     gate_registry: gateRegistry,
    //     network_node_registry: networkNodeRegistry,
    //     // jump_history: jumpHistoryData,
    //     // jump_history_by_character: jumpHistoryByCharacterData,
    //     // killmail_registry: killmailRegistryData,
    //     // blacklist: blacklistData,
    //     // character_bounties: characterBountiesData,
    //     // tribe_bounties: tribeBountiesData,
    // };

    // return fta;
}

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