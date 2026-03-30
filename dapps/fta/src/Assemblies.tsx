import { Box, Heading, Button, Tabs, Text } from "@radix-ui/themes";
import { abbreviateAddress, useConnection, CharacterInfo } from "@evefrontier/dapp-kit";
import { useCurrentAccount } from "@mysten/dapp-kit-react";
import { NetworkNodeTransfer } from "./NetworkNodeTransfer";
import { useEffect, useState } from "react";
import { getOwnedAssembliesByType } from "./queries/assemblies";
import { worldOriginalPackageId } from "./utils";
import { OwnedAssembliesByTypeResponse } from "./queries/assemblies";

type AssembliesProps = {
    characters: CharacterInfo[];
};

export function Assemblies(props: AssembliesProps) {
    const [networkNodes, setNetworkNodes] = useState<CharacterInfo[] | null>(null);

    useEffect(() => {
        console.log("Loading Assemblies!");
        async function load() {
            let networkNodes: OwnedAssembliesByTypeResponse[] = [];
            let gates: OwnedAssembliesByTypeResponse[] = [];
            await Promise.all(props.characters.map(async char => {
                const networkNodesPromise = await getOwnedAssembliesByType(char.id, `network_node::NetworkNode`);
                const gatesPromise = await getOwnedAssembliesByType(char.id, "gate::Gate");
                networkNodes = networkNodes.concat(networkNodesPromise);
                gates = gates.concat(gatesPromise);
            }));

            console.log("Network nodes:", networkNodes);
            console.log("Gates:", gates);
        }
        load();
    }, [props.characters]);

    return (
        <Box>
        </Box>
    );
}
