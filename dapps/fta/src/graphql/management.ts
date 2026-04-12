import {
    executeGraphQLQuery,
} from "@evefrontier/dapp-kit";
import { worldOriginalPackageId } from "../utils";
import { FTA_ORIGINAL_ID } from "../../libs/auto-constants";
import { TypeRepr } from "@evefrontier/dapp-kit";
import { ManagementCapSchema, ManagementCapType } from "../types/management-cap";

interface GetManagementCapsResponse {
    object: {
        objects: {
            nodes: {
                contents: {
                    type: TypeRepr,
                    json: {
                        id: string,
                        authorized_object_id: string,
                        object_registration_id: string,
                    }
                }
            }[]
        }
    }
}

export async function getOwnedManagementCaps(player_profile_address: string): Promise<[Record<string, ManagementCapType>, Record<string, ManagementCapType>]> {
    const query = `
query GetOwnedManagementCaps($playerProfileAddr: SuiAddress!, $objectType: String){
object(address: $playerProfileAddr) {
    objects (
        filter:  {
            type: $objectType
        }
    ){
        nodes {
            contents {
                type {
                    repr
                }
                json
            }
        }
    }
}
}`;

    const gatesPromise = executeGraphQLQuery<GetManagementCapsResponse>(
        query,
        {
            playerProfileAddr: player_profile_address,
            objectType: `${FTA_ORIGINAL_ID}::management_cap::ManagementCap<${worldOriginalPackageId()}::gate::Gate>`,
        },
    );
    const nnPromise = executeGraphQLQuery<GetManagementCapsResponse>(
        query,
        {
            playerProfileAddr: player_profile_address,
            objectType: `${FTA_ORIGINAL_ID}::management_cap::ManagementCap<${worldOriginalPackageId()}::network_node::NetworkNode>`,
        },
    );
    const gateManagementCaps = await gatesPromise;
    if (!gateManagementCaps.data) {
        throw new Error(`Failed to fetch management caps for gates: ${gateManagementCaps.errors?.map(e => e.message).join(", ")}`);
    }
    const nnManagementCaps = await nnPromise;
    if (!nnManagementCaps.data) {
        throw new Error(`Failed to fetch management caps for network nodes: ${nnManagementCaps.errors?.map(e => e.message).join(", ")}`);
    }

    const transformedGateCaps = gateManagementCaps.data.object.objects.nodes.reduce((acc, node) => {
        const cap = ManagementCapSchema.parse(node.contents.json);
        acc[cap.authorized_object_id] = cap;
        return acc;
    }, {} as Record<string, ManagementCapType>);

    const transformedNNCaps = nnManagementCaps.data.object.objects.nodes.reduce((acc, node) => {
        const cap = ManagementCapSchema.parse(node.contents.json);
        acc[cap.authorized_object_id] = cap;
        return acc;
    }, {} as Record<string, ManagementCapType>);

    return [transformedGateCaps, transformedNNCaps];
}