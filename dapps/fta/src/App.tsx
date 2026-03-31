import { Box, Flex, Section, Link, AlertDialog, Button } from "@radix-ui/themes";
import { useCurrentAccount } from "@mysten/dapp-kit-react";
import { Disconnected } from "./Disconnected";
import { Connected } from "./Connected";
import { useFTA } from "./hooks/useFTA";
import { Loading } from "./components/loading";
import logoUrl from '../assets/logo.png';
import { useNotification } from "@evefrontier/dapp-kit";

function App() {

  const account = useCurrentAccount();
  const fta = useFTA();
  const notifier = useNotification();

  const content = fta.loading ? <Loading /> : account?.address ? (
    <Connected />
  ) : (
    <Disconnected />
  );

  return (
    <Flex
      direction={"column"}
      justify={"center"}
      align="center"
      height="100vh"
    >
      <Flex
        direction="row"
        position="absolute"
        align="center"
        top="0"
        left="0"
        p="3"
        gap="2"
      >
        <Link href="/fta/docs/">Documentation</Link>
      </Flex>
      <Box>
        <Flex justify={"center"}>
          {
            notifier.notification.isOpen ? (
              <AlertDialog.Root open={true}>
                <AlertDialog.Content maxWidth="450px">
                  <AlertDialog.Title>Error</AlertDialog.Title>
                  <AlertDialog.Description size="2">
                    {notifier.notification.message}
                  </AlertDialog.Description>

                  <Flex gap="3" mt="4" justify="end">
                    <AlertDialog.Cancel>
                      <Button variant="soft" color="gray" onClick={notifier.handleClose}>
                        OK
                      </Button>
                    </AlertDialog.Cancel>
                  </Flex>
                </AlertDialog.Content>
              </AlertDialog.Root>
            ) : null
          }
          <img
            src={logoUrl}
            alt="FTA Logo"
            style={{
              objectFit: "cover",
              width: "50%",
            }}
          />
        </Flex>
        <Section size="1">
          {content}
        </Section>
      </Box>
    </Flex>
  );
}

export default App;
