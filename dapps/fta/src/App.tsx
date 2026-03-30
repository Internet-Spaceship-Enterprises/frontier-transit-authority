import { Box, Container, Flex, Heading } from "@radix-ui/themes";
import { useCurrentAccount } from "@mysten/dapp-kit-react";
import { NotConnected } from "./NotConnected";
import { Connected } from "./Connected";

function App() {

  const account = useCurrentAccount();

  const content = account?.address ? (
    <Connected />
  ) : (
    <NotConnected />
  );
  return (
    <Flex
      position="sticky"
      px="4"
      py="2"
      direction="row"
      style={{
        display: "flex",
        justifyContent: "space-between",
      }}
    >
      {content}
    </Flex>
  )
}

export default App;
