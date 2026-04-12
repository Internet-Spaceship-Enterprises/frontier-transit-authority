import {
    executeGraphQLQuery,
} from "@evefrontier/dapp-kit";
import { GET_LOCATION_REGISTRY } from "./queries";
import { LOCATION_REGISTRY } from "../../libs/constants";
import { CoordinatesSchema, CoordinatesType, LocationRegistry } from "../types/location";
import { getTableData } from "./tables";

interface GetLocationRegistryResponse {
    object: {
        asMoveObject: {
            contents: {
                json: {
                    id: string,
                    locations: {
                        id: string,
                        size: number,
                    }
                }
            }
        }
    }
}

export async function getLocationRegistry(): Promise<LocationRegistry> {
    const result = await executeGraphQLQuery<GetLocationRegistryResponse>(
        GET_LOCATION_REGISTRY,
        {
            address: LOCATION_REGISTRY,
        },
    );
    if (!result.data) {
        throw new Error("Failed to fetch location registry data");
    }

    const locationsRegistry = await getTableData<string, CoordinatesType>(
        result.data.object.asMoveObject.contents.json.locations.id, CoordinatesSchema, false);

    return locationsRegistry;
}