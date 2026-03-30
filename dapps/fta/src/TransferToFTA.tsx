import { Box, Flex, TextField, Button } from "@radix-ui/themes";
import { registerNetworkNode } from "./fta/transfer-network-node";
import { useState } from "react";
import { useDAppKit, useCurrentAccount } from "@mysten/dapp-kit-react";

const ftaObjectId = "0x87df6923015657a9442d25d003bb5127d27fa7d36435adbf496426ee4feeca98";
const characterObjectId = "0xe77a0263c0fcd8298318561fcafb34dba78476549e1af195cc37a7348d8a6b0e";

export function TransferToFTA() {
    const dAppKit = useDAppKit();
    const [networkNodeId, setNetworkNodeId] = useState("");
    const [gateId, setGateId] = useState("");
    const account = useCurrentAccount();

    async function transferNetworkNode() {
        await registerNetworkNode(dAppKit, ftaObjectId, networkNodeId, characterObjectId, 999n, account!.address);
    }

    return (
        <Flex direction="row" gap="4" align="center">
            <Box maxWidth="450px">
                <TextField.Root
                    size="3"
                    placeholder="Enter the Network Node Assembly ID…"
                    value={networkNodeId}
                    onChange={(e) => setNetworkNodeId(e.target.value)}
                />
            </Box>
            <Button onClick={transferNetworkNode}>
                Bookmark
            </Button>
        </Flex>
    );
}
