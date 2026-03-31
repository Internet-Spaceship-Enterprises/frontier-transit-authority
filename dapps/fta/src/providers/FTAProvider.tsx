import {
    ReactNode,
    useState,
    createContext,
    useEffect,
    useCallback,
    useRef,
} from "react";
import {
    Assemblies,
    AssemblyType,
} from "@evefrontier/dapp-kit";
import { FTAContextType, FTAType } from "../types/fta";
import { getOwnedAssembliesByType } from "../queries/assemblies";
import { FTA_OBJECT_ID } from "../../libs/auto-constants";
import { getFTA } from "../queries/fta";
import { GateWithOwnerCap } from "../types/gate";
import { CoordinatesType } from "../types/location";
import { getLocationRegistry } from "../queries/locations";

const POLLING_INTERVAL = 5000; // 5 seconds

/** @category Providers */
export const FTAContext = createContext<FTAContextType>({
    loading: true,
    error: null,
    fta: null,
    gates: null,
    locations: null,
    refetch: async () => { },
});

const FTAProvider = ({ children }: { children: ReactNode }) => {
    const [locations, setLocations] = useState<Record<string, CoordinatesType> | null>(null);
    const [gates, setGates] = useState<Record<string, GateWithOwnerCap> | null>(null);
    const [fta, setFTA] = useState<FTAType | null>(null);
    const pollingRef = useRef<NodeJS.Timeout | null>(null);
    const lastDataHashRef = useRef<string | null>(null);
    const [loading, setLoading] = useState<boolean>(true);
    const [error, setError] = useState<string | null>(null);

    // Fetch all of the FTA info
    const fetchData = useCallback(
        async (isInitialFetch = false) => {

            if (isInitialFetch) {
                setLoading(true);
            }
            setError(null);

            try {
                console.info(
                    "FTAProvider: Fetching FTA data",
                );

                const ftaPromise = getFTA();
                const gatesPromise = getOwnedAssembliesByType(FTA_OBJECT_ID, "gate::Gate");
                const locationsPromise = await getLocationRegistry();

                //const nnPromise = getOwnedAssembliesByType(FTA_OBJECT_ID, "network_node::NetworkNode");

                // Transform the gates to the desired format
                const gatesResult = (await gatesPromise).map((gate) => {
                    return {
                        assembly: gate.assembly as AssemblyType<Assemblies.SmartGate>,
                        owner_cap: gate.owner_cap,
                    } as GateWithOwnerCap;
                }).reduce((acc, gate, _) => {
                    acc[gate.assembly.id] = gate;
                    return acc;
                }, {} as Record<string, GateWithOwnerCap>);

                // // Transform the network nodes to the desired format
                // const nnResult = (await nnPromise).map((nn) => {
                //     return {
                //         assembly: nn.assembly as AssemblyType<Assemblies.NetworkNode>,
                //         owner_cap: nn.owner_cap,
                //     } as NetworkNodeWithOwnerCap;
                // }).reduce((acc, nn, _) => {
                //     acc[nn.assembly.id] = nn;
                //     return acc;
                // }, {} as Record<string, NetworkNodeWithOwnerCap>);

                const ftaResult = await ftaPromise;

                const locationsResult = await locationsPromise;

                // Create a hash of the data to check for changes
                const dataHash = JSON.stringify({
                    //locations: locationsResult,
                    fta: ftaResult,
                    gates: gatesResult,
                    //network_nodes: nnResult,
                });


                // Only update state if the data changed (optimization for polling)
                if (isInitialFetch || lastDataHashRef.current !== dataHash) {
                    console.info("FTAProvider: FTA data updated");
                    lastDataHashRef.current = dataHash;

                    setFTA(ftaResult);
                    setGates(gatesResult);
                    setLocations(locationsResult);

                    console.log("Gates: ", gatesResult);
                    console.log("FTA: ", ftaResult);
                    console.log("Locations: ", locationsResult);
                }
                setError(null);
            } catch (err: unknown) {
                console.error("FTAProvider: Query error:", err);
                setError(err instanceof Error ? err.message : "Failed to fetch object");
            } finally {
                if (isInitialFetch) {
                    setLoading(false);
                }
            }
        },
        [],
    );

    // Fetch and poll for object data
    useEffect(() => {
        // Initial fetch
        fetchData(true);

        // Set up polling
        pollingRef.current = setInterval(() => {
            fetchData(false);
        }, POLLING_INTERVAL);

        console.info(
            "FTAProvider: Started polling"
        );

        return () => {
            if (pollingRef.current) {
                clearInterval(pollingRef.current);
                pollingRef.current = null;
                console.info("FTAProvider: Stopped polling");
            }
            lastDataHashRef.current = null;
        };
    }, [
        fetchData,
    ]);

    const handleRefetch = useCallback(async () => {
        await fetchData(true);
    }, []);

    // Refetch with retries after a mutation (e.g. metadata save)
    // so the indexer can catch up.
    const handleRefetchWithRetries = useCallback(async () => {
        await handleRefetch();
        await new Promise<void>((resolve) => {
            setTimeout(resolve, 1500);
        });
        await handleRefetch();
    }, [handleRefetch]);

    return (
        <FTAContext.Provider
            value={{
                fta: fta,
                loading: loading,
                error: error,
                gates: gates,
                locations: locations,
                // network_nodes: network_nodes,
                refetch: handleRefetchWithRetries,
            }}
        >
            {children}
        </FTAContext.Provider>
    );
};

export default FTAProvider;