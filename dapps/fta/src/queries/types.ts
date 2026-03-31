import { TypeRepr, ObjectNodes, AsMoveObjectRef, MoveObjectData } from "@evefrontier/dapp-kit";

/** @category GraphQL Types */
export interface OwnerCap {
    id: string;
    authorized_object_id: string;
}

/** @category GraphQL Types */
export interface ObjectWithContentsNode {
    address: string;
    version: number;
    asMoveObject: {
        contents: { json: Record<string, unknown>; type: TypeRepr };
    } | null;
}

export interface OwnedAssembliesNode {
    contents: {
        type: TypeRepr;
        json: OwnerCap;
        extract: AsMoveObjectRef<MoveObjectData>
    }
}

/** @category GraphQL Types */
export interface GetOwnedAssembliesResponse {
    object: {
        objects: ObjectNodes<OwnedAssembliesNode>
    }
}

export interface GetAssemblyByIdResponse {
    object: {
        asMoveObject: MoveObjectData
    }
}

export interface JumpEstimate {
    prepared_at: number;
    character_id: string;
    source_gate_id: string;
    destination_gate_id: string;
    source_gate_fee: number;
    destination_gate_fee: number;
    source_network_node_fee: number
    destination_network_node_fee: number;
    scaling_factor: number;
    penalty_factor: number;
    bounty_fee: number;
    developer_fee: number;
    validity_duration: number;
    precision_factor: number;
}

export interface JumpQuote {
    id: string;
    estimate: JumpEstimate;
    destination_gate_fee: number;
    source_network_node_fee: number
    destination_network_node_fee: number;
    scaling_factor: number;
    penalty_factor: number;
    bounty_fee: number;
    developer_fee: number;
    validity_duration: number;
    precision_factor: number;
}

export interface GetJumpQuoteResponse {
    object: {
        asMoveObject: {
            contents: {
                type: TypeRepr;
                json: JumpQuote;
            }
        }
    }
}

export interface JumpPermit {
    id: string;
    character_id: string;
    route_hash: string;
    expires_at_timestamp_ms: number;
}

export interface GetJumpPermitResponse {
    object: {
        asMoveObject: {
            contents: {
                type: TypeRepr;
                json: JumpPermit;
            }
        }
    }
}