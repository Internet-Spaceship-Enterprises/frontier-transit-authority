import { Box, Heading, Button, Tabs, Text } from "@radix-ui/themes";
import { abbreviateAddress, useConnection, CharacterInfo } from "@evefrontier/dapp-kit";
import { useCurrentAccount } from "@mysten/dapp-kit-react";
import { NetworkNodeTransfer } from "./NetworkNodeTransfer";
import { useEffect, useState } from "react";
import { getWalletCharacters } from "./queries/characters";
import { Assemblies } from "./Assemblies";
import { Operator } from "./Operator";


export function Connected() {
    const { handleDisconnect } = useConnection();
    const account = useCurrentAccount();
    const [playerProfiles, setPlayerProfiles] = useState<CharacterInfo[] | null>(null);
    const [loading, setLoading] = useState<boolean>(true);

    useEffect(() => {
        console.log("Loading characters!");
        async function load() {
            const chars = await getWalletCharacters(account!.address);
            setPlayerProfiles(chars);
            setLoading(false);
        }
        load();
    }, [account?.address]);

    return (<Box>
        <Heading as="h1">Frontier Transit Authority</Heading>
        <Button onClick={() => { handleDisconnect() }}>
            {abbreviateAddress(account?.address)}
        </Button>
        {
            loading ? (
                <Text>Loading...</Text>
            ) : (
                <Tabs.Root defaultValue="operator">
                    <Tabs.List>
                        <Tabs.Trigger value="traveler">Traveler</Tabs.Trigger>
                        <Tabs.Trigger value="operator">Operator</Tabs.Trigger>
                    </Tabs.List>

                    <Box pt="3">
                        <Tabs.Content value="traveler">
                        </Tabs.Content>

                        <Tabs.Content value="operator">
                            <Operator characters={playerProfiles!} />
                        </Tabs.Content>
                    </Box>
                </Tabs.Root>

            )
        }
    </Box>);
}
