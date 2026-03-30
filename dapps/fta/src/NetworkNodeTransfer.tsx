import { Box, Heading, Button, Tabs, Text, Flex, TextField, Spinner } from "@radix-ui/themes";
import { abbreviateAddress, useConnection } from "@evefrontier/dapp-kit";
import { useState } from "react";
import { useCurrentAccount, useDAppKit } from "@mysten/dapp-kit-react";
import { Link2Icon, LightningBoltIcon } from "@radix-ui/react-icons"
import { registerNetworkNode } from "./transactions/register-network-node";
import { FTA_OBJECT_ID } from "../libs/auto-constants";
import { fetchAssemblyInfo } from "./queries";

export function NetworkNodeTransfer() {
    const dAppKit = useDAppKit();
    const account = useCurrentAccount();
    const [processing, setProcessing] = useState(false);
    const [networkNodeId, setNetworkNodeId] = useState("");


    async function transferNetworkNode() {
        setProcessing(true);
        const info = await fetchAssemblyInfo(networkNodeId);
        if (!info?.assembly) {
            console.log("Invalid assembly");
        } else {
            console.log("Assembly info:", info);
        }
        // await registerNetworkNode(dAppKit, FTA_OBJECT_ID, networkNodeId, characterObjectId, 999n, account!.address);
        //await new Promise(resolve => setTimeout(resolve, 2000));
        setProcessing(false);
    }

    return (
        <Box>
            <Flex direction="column" gap="3">
                <Box maxWidth="200px">
                    <Text size="1">Network node ID:</Text>
                    <TextField.Root size="2" placeholder="Network node ID..." value={networkNodeId} onChange={(e) => setNetworkNodeId(e.target.value)}>
                        <TextField.Slot>
                            <LightningBoltIcon height="16" width="16" />
                        </TextField.Slot>
                    </TextField.Root>
                    <Button onClick={transferNetworkNode} disabled={processing}>
                        <Spinner loading={processing}>
                            <Link2Icon />
                        </Spinner>
                        Register
                    </Button>
                </Box>
            </Flex>
        </Box>
    );
}
