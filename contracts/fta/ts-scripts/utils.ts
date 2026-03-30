import { bcs } from "@mysten/sui/bcs";
import { SuiJsonRpcClient } from "@mysten/sui/jsonRpc";
import { getConfig, MODULES } from "../../../ts-scripts/utils/config";
import { devInspectMoveCallFirstReturnValueBytes } from "../../../ts-scripts/utils/dev-inspect";
import { FTA_PACKAGE_ID, FTA_OBJECT_ID } from "./config";

export async function getNetworkNodeOwnerCapId(
    networkNodeId: string,
    client: SuiJsonRpcClient,
    config: ReturnType<typeof getConfig>,
    senderAddress?: string
): Promise<string | null> {
    try {
        const bytes = await devInspectMoveCallFirstReturnValueBytes(client, {
            target: `${config.packageId}::${MODULES.NETWORK_NODE}::owner_cap_id`,
            senderAddress,
            arguments: (tx) => [tx.object(networkNodeId)],
        });

        if (!bytes) {
            console.warn("Error checking ownercap id");
            return null;
        }
        return bcs.Address.parse(bytes);
    } catch (error) {
        console.warn("Failed to get ownerCap:", error instanceof Error ? error.message : error);
        return null;
    }
}

export async function getGateOwnerCapId(
    gateId: string,
    client: SuiJsonRpcClient,
    config: ReturnType<typeof getConfig>,
    senderAddress?: string
): Promise<string | null> {
    try {
        const bytes = await devInspectMoveCallFirstReturnValueBytes(client, {
            target: `${config.packageId}::${MODULES.GATE}::owner_cap_id`,
            senderAddress,
            arguments: (tx) => [tx.object(gateId)],
        });

        if (!bytes) {
            console.warn("Error checking gate owner cap ID");
            return null;
        }

        return bcs.Address.parse(bytes);
    } catch (error) {
        console.warn("Failed to get gate owner cap ID:", error instanceof Error ? error.message : error);
        return null;
    }
}

export async function getEnergySourceId(
    gateId: string,
    client: SuiJsonRpcClient,
    config: ReturnType<typeof getConfig>,
    senderAddress?: string
): Promise<string | null> {
    try {
        const bytes = await devInspectMoveCallFirstReturnValueBytes(client, {
            target: `${config.packageId}::${MODULES.GATE}::energy_source_id`,
            senderAddress,
            arguments: (tx) => [tx.object(gateId)],
        });

        if (!bytes) {
            console.warn("Error checking energy source id");
            return null;
        }

        return bcs.option(bcs.Address).parse(bytes);
    } catch (error) {
        console.warn("Failed to get energy source ID:", error instanceof Error ? error.message : error);
        return null;
    }
}

export async function gateNetworkNodeRegistered(
    gateId: string,
    client: SuiJsonRpcClient,
    senderAddress?: string
): Promise<boolean | null> {

    try {
        const bytes = await devInspectMoveCallFirstReturnValueBytes(client, {
            target: `${FTA_PACKAGE_ID}::fta::gate_network_node_registered`,
            senderAddress,
            arguments: (tx) => [tx.object(FTA_OBJECT_ID), tx.object(gateId)],
        });

        if (!bytes) {
            console.warn("Error checking ownercap id");
            return null;
        }
        return bcs.Bool.parse(Uint8Array.from(bytes));;
    } catch (error) {
        console.warn("Failed to get ownerCap:", error instanceof Error ? error.message : error);
        return null;
    }
}