import {
    executeGraphQLQuery,
    GraphQLResponse,
} from "@evefrontier/dapp-kit";
import { GET_TABLE } from "./queries";
import { ZodObject } from "zod";
import { DynamicFields } from "./fta";

interface GetTableResponse<K, V> {
    address: {
        addressAt: {
            dynamicFields: DynamicFields<K, V>
        }
    }
}

export async function getTableData<K extends string | number | symbol, V>(tableId: string, schema: ZodObject<any>, isLinkedTable: boolean): Promise<Record<K, V>> {
    let results: Record<K, V> = {} as Record<K, V>;
    let next: string | null = null;

    while (true) {
        const page: GraphQLResponse<GetTableResponse<K, V>> = await executeGraphQLQuery<GetTableResponse<K, V>>(
            GET_TABLE,
            {
                address: tableId,
                first: 40,
                after: next,
            },
        );
        if (!page.data) {
            throw new Error(`Failed to fetch table data (${tableId}): ${page.errors?.map(e => e.message).join(", ")}`);
        }
        page.data.address.addressAt.dynamicFields.nodes.forEach((node) => {
            const key = node.name.json as K;
            const value = schema.parse(isLinkedTable ? node.value.json.value : node.value.json) as V;
            results[key] = value;
        });
        if (!page.data.address.addressAt.dynamicFields.pageInfo.hasNextPage) {
            break;
        }
        next = page.data.address.addressAt.dynamicFields.pageInfo.endCursor;
    }

    return results;
}