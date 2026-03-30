import { Box, Container, Flex, Heading } from "@radix-ui/themes";
import { WalletStatus } from "./WalletStatus";
import { AssemblyInfo } from "./AssemblyInfo";
import { abbreviateAddress, useConnection, getEveWorldPackageId } from "@evefrontier/dapp-kit";
import { useCurrentAccount } from "@mysten/dapp-kit-react";
import { TransferToFTA } from "./TransferToFTA";
import {
  useNotification,
  useSmartObject,
  CharacterInfo,
} from "@evefrontier/dapp-kit";
import { useEffect, useState } from "react";
import { fetchWalletCharacters } from "./queries";


function App() {
  /**
   * STEP 2 — Wallet connection
   *
   * useConnection() (@evefrontier/dapp-kit) → handleConnect, handleDisconnect;
   * isConnected, walletAddress, hasEveVault. useCurrentAccount()
   * (@mysten/dapp-kit-react) → account (e.g. account.address) for UI. abbreviateAddress()
   * (@evefrontier/dapp-kit) for display.
   */
  const [userCharacter, setUserCharacter] = useState<CharacterInfo | null>(
    null,
  );
  const { handleConnect, handleDisconnect } = useConnection();
  const account = useCurrentAccount();
  const connected = !!account;

  // Get the character from the wallet
  // useEffect(() => {
  //   if (connected) {
  //     fetchWalletCharacters(account!.address).then((characterInfo) => {
  //       if (characterInfo) {
  //         setUserCharacter(characterInfo);
  //       }
  //     });
  //   }
  // }, [connected, account?.address]);

  return (
    <Box style={{ padding: "20px" }}>
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
        <Heading>Frontier Transit Authority</Heading>

        {/* STEP 2 — Connect/disconnect; show abbreviated address in header. */}
        <button
          onClick={() =>
            account?.address ? handleDisconnect() : handleConnect()
          }
        >
          {account ? abbreviateAddress(account?.address) : "Connect Wallet"}
        </button>
      </Flex>
      {/* STEP 3 — Same hooks (useConnection, useCurrentAccount) drive WalletStatus; state stays in sync. */}
      <WalletStatus />
      {/* <AssemblyInfo /> */}
      <TransferToFTA />
    </Box>
  );
}

export default App;
