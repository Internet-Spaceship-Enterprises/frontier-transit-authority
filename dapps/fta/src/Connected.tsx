import { Flex, Box, Button, Tabs, Text, Strong } from "@radix-ui/themes";
import { abbreviateAddress, useConnection, CharacterInfo } from "@evefrontier/dapp-kit";
import { useCurrentAccount } from "@mysten/dapp-kit-react";
import { useEffect, useState } from "react";
import { getWalletCharacters } from "./queries/characters";
import { Operator } from "./Operator";
import { Traveler } from "./Traveler";
import { Loading } from "./components/loading";


export function Connected() {
    const { handleDisconnect } = useConnection();
    const account = useCurrentAccount();
    const [, setPlayerProfiles] = useState<CharacterInfo[] | null>(null);
    const [character, setCharacter] = useState<CharacterInfo | null>(null);
    const [loading, setLoading] = useState<boolean>(true);

    useEffect(() => {
        async function load() {
            const chars = await getWalletCharacters(account!.address);
            setPlayerProfiles(chars);
            // TODO: drop down in top right to select character if multiple
            setCharacter(chars[0]);
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
                        <Tabs.Root defaultValue="traveler">
                            <Tabs.List className="bigTabs" justify={"center"}>
                                <Tabs.Trigger value="traveler">Traveler</Tabs.Trigger>
                                <Tabs.Trigger value="operator">Operator</Tabs.Trigger>
                            </Tabs.List>

                            <Box pt="3">
                                <Tabs.Content value="traveler">
                                    <Traveler character={character!} />
                                </Tabs.Content>

                                <Tabs.Content value="operator">
                                    <Operator character={character!} />
                                </Tabs.Content>
                            </Box>
                        </Tabs.Root>
                    </Box>
                )
            }
        </Flex>
    );
}
