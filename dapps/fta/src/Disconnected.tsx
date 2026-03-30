import { Button, Box } from "@radix-ui/themes";
import { useConnection } from "@evefrontier/dapp-kit";

export function Disconnected() {
    const { handleConnect } = useConnection();
    return (
        <Box justifySelf="center">
            <Button size={"3"} onClick={() => { handleConnect() }}>
                Connect
            </Button>
        </Box>
    );
}
