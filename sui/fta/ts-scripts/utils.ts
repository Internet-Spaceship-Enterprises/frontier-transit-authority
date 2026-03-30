import { bcs } from "@mysten/sui/bcs";
import { SuiJsonRpcClient } from "@mysten/sui/jsonRpc";
import { getConfig, MODULES } from "../../../ts-scripts/utils/config";
import { devInspectMoveCallFirstReturnValueBytes } from "../../../ts-scripts/utils/dev-inspect";

export async function getGateOwnerCap(
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
            console.warn("Error checking ownercap id");
            return null;
        }

        return bcs.Address.parse(bytes);
    } catch (error) {
        console.warn("Failed to get ownerCap:", error instanceof Error ? error.message : error);
        return null;
    }
}

export async function getNetworkNodeOwnerCap(
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

        return bcs.Address.parse(bytes);
    } catch (error) {
        console.warn("Failed to get energy source ID:", error instanceof Error ? error.message : error);
        return null;
    }
}