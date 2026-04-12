import { Flex, Box, Button, Tabs, Text, Strong } from "@radix-ui/themes";
import { useConnection, CharacterInfo } from "@evefrontier/dapp-kit";
import { useCurrentAccount } from "@mysten/dapp-kit-react";
import { useEffect, useState } from "react";
import { getWalletCharacters } from "./graphql/characters";
import { Operator } from "./Operator";
import { Traveler } from "./Traveler";
import { Loading } from "./components/loading";
import { useFTA } from "./hooks/useFTA";
import { ManagementCapType } from "./types/management-cap";
import { getOwnedManagementCaps } from "./graphql/management";


export function Connected() {
    const { handleDisconnect } = useConnection();
    const account = useCurrentAccount();
    const [, setPlayerProfiles] = useState<CharacterInfo[] | null>(null);
    const [character, setCharacter] = useState<CharacterInfo | null>(null);
    const [gateManagementCaps, setGateManagementCaps] = useState<Record<string, ManagementCapType> | null>(null);
    const [networkNodeManagementCaps, setNetworkNodeManagementCaps] = useState<Record<string, ManagementCapType> | null>(null);
    const [loading, setLoading] = useState<boolean>(true);
    const fta = useFTA();

    useEffect(() => {
        async function load() {
            const profiles = await getWalletCharacters(account!.address);
            setPlayerProfiles(profiles);
            // TODO: drop down in top right to select character if multiple
            setCharacter(profiles[0]);

            const [gateCaps, nnCaps] = await getOwnedManagementCaps(profiles[0].id);
            console.log("Gate Management Caps:", gateCaps);
            console.log("Network Node Management Caps:", nnCaps);
            setGateManagementCaps(gateCaps);
            setNetworkNodeManagementCaps(nnCaps);
            setLoading(false);
        }
        load();
    }, [account?.address]);

    return (
        <Flex direction="column" align="start" width="100%">
            <Flex
                direction="row"
                position="absolute"
                align="center"
                top="0"
                right="0"
                p="3"
                gap="2"
            >
                <Text><Strong>Connected as:</Strong> {character?.name}</Text>
                <Button onClick={() => { handleDisconnect() }}>
                    Disconnect
                </Button>
            </Flex>
            {
                loading ? (
                    <Loading />
                ) : (
                    <Box alignSelf={"center"}>
                        <Tabs.Root defaultValue={fta.assemblyId ? "traveler" : "operator"}>
                            <Tabs.List className="bigTabs" justify={"center"}>
                                <Tabs.Trigger value="traveler">Traveler</Tabs.Trigger>
                                <Tabs.Trigger value="operator">Operator</Tabs.Trigger>
                            </Tabs.List>

                            <Box pt="3">
                                <Tabs.Content value="traveler">
                                    <Traveler character={character!} />
                                </Tabs.Content>

                                <Tabs.Content value="operator">
                                    <Operator character={character!} gateManagementCaps={gateManagementCaps} networkNodeManagementCaps={networkNodeManagementCaps} />
                                </Tabs.Content>
                            </Box>
                        </Tabs.Root>
                    </Box>
                )
            }
        </Flex>
    );
}
