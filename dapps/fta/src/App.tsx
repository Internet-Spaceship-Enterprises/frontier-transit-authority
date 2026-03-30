import { Box, Container, Flex, Heading, Section } from "@radix-ui/themes";
import { useCurrentAccount } from "@mysten/dapp-kit-react";
import { Disconnected } from "./Disconnected";
import { Connected } from "./Connected";

function App() {

  const account = useCurrentAccount();

  const content = account?.address ? (
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
      <Box>
        <Flex justify={"center"}>
          <img
            src="/assets/logo.png"
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
