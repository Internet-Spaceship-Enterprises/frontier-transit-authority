import React from "react";
import ReactDOM from "react-dom/client";
import "@radix-ui/themes/styles.css";
import "./styles/main.css";

import App from "./App.tsx";
import { Theme } from "@radix-ui/themes";
import { dAppKit } from "@evefrontier/dapp-kit";
import { NotificationProvider } from "@evefrontier/dapp-kit";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { DAppKitProvider } from "@mysten/dapp-kit-react";
import { VaultProvider } from "@evefrontier/dapp-kit";
import FTAProvider from "./providers/FTAProvider.tsx";

const queryClient = new QueryClient();

/** STEP 1 — EveFrontierProvider(queryClient) wraps App; composes QueryClientProvider (React Query), DAppKitProvider (Mysten Sui client + wallet), VaultProvider (EVE wallet/connection), SmartObjectProvider (GraphQL assembly/context), NotificationProvider (toasts). */
ReactDOM.createRoot(document.getElementById("root")!).render(
  // <React.StrictMode>
  <Theme appearance="dark">
    <QueryClientProvider client={queryClient}>
      <DAppKitProvider dAppKit={dAppKit}>
        <FTAProvider>
          <VaultProvider>
            <NotificationProvider>
              <App />
            </NotificationProvider>
          </VaultProvider>
        </FTAProvider>
      </DAppKitProvider>
    </QueryClientProvider>
  </Theme>
  // </React.StrictMode>,
);
