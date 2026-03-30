import { Button } from "@radix-ui/themes";
import { useConnection } from "@evefrontier/dapp-kit";

export function NotConnected() {
    const { handleConnect } = useConnection();
    return (
        <Button onClick={() => { handleConnect() }}>
            Connect
        </Button>
    );
}
