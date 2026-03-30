import {
    // Core fetch functions
    executeGraphQLQuery, // Raw GraphQL execution

    // Transformation functions
    transformToAssembly,
    AssemblyType,
    Assemblies,

} from "@evefrontier/dapp-kit";
import { GetOwnedAssembliesResponse, OwnedAssembliesNode } from "./types";
import { worldOriginalPackageId } from "../utils";

export interface OwnedAssembliesByTypeResponse {
    assembly: AssemblyType<Assemblies>,
    owner_cap: {
        type: string,
        id: string,
        authorized_object_id: string,
    }
};

export async function getOwnedAssembliesByType(playerProfileAddr: string, objectType: string): Promise<OwnedAssembliesByTypeResponse[]> {
    const query = `
  query GetOwnedObjectsByType($playerProfileAddr: SuiAddress!, $objectType: String){
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
                   extract(path: "authorized_object_id") {
                        asAddress {
                            asObject {
                                asMoveObject {
                                    contents {
                                        type {
                                            repr
                                        }
                                        json
                                    }
                                }
                            }
                        }
                   }
                }
            }
        }
    }
  }`

    const ownerCapType = `${worldOriginalPackageId()}::access::OwnerCap<${worldOriginalPackageId()}::${objectType}>`;
    const result = await executeGraphQLQuery<GetOwnedAssembliesResponse>(
        query,
        {
            playerProfileAddr: playerProfileAddr,
            objectType: ownerCapType,
        },
    );

    const promises = result.data?.object?.objects.nodes.filter(node => node.contents.extract.asAddress && node.contents.extract.asAddress?.asObject && node.contents.extract.asAddress?.asObject?.asMoveObject).map(async (node: OwnedAssembliesNode): Promise<OwnedAssembliesByTypeResponse> => ({
        owner_cap: {
            type: node.contents.type.repr,
            id: node.contents.json.id,
            authorized_object_id: node.contents.json.authorized_object_id,
        },
        assembly: (await transformToAssembly("", node.contents.extract.asAddress?.asObject?.asMoveObject!))!,
    }))!;
    const mapped = await Promise.all(promises);
    console.log(mapped);

    return mapped;
}