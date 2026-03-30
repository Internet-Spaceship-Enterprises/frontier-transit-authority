import "dotenv/config";
import { Transaction } from "@mysten/sui/transactions";
import {
    getEnvConfig,
    handleError,
    hydrateWorldConfig,
    initializeContext,
    requireEnv,
} from "../../../ts-scripts/utils/helper";
import { executeSponsoredTransaction } from "../../../ts-scripts/utils/transaction";
import { keypairFromPrivateKey } from "../../../ts-scripts/utils/client";

async function transferEve(
    ctx: ReturnType<typeof initializeContext>,
    playerAddress: string,
    adminAddress: string,
    adminKeypair: ReturnType<typeof keypairFromPrivateKey>
) {
    const { client, keypair: playerKeypair, config } = ctx;
    let tx = new Transaction();

    tx.setSender(adminAddress);
    tx.setGasOwner(adminAddress);

    tx.moveCall({
        target: `${process.env.ASSETS_PACKAGE_ID!}::EVE::transfer_from_treasury`,
        arguments: [
            tx.object(process.env.EVE_TREASURY_OBJECT_ID!),
            tx.object(process.env.EVE_ADMIN_CAP_ID!),
            tx.pure.u64(1000000000),
            tx.pure.address(playerAddress),
        ],
    });

    const result = await client.signAndExecuteTransaction({
        transaction: tx,
        signer: adminKeypair,
        options: { showObjectChanges: true, showEffects: true, showEvents: true },
    });


    console.log("\nEve successfully transferred!");
    console.log("Transaction digest:", result.digest);
}

async function main() {
    try {
        const env = getEnvConfig();
        const playerKey = requireEnv("PLAYER_B_PRIVATE_KEY");
        const playerCtx = initializeContext(env.network, playerKey);
        await hydrateWorldConfig(playerCtx);
        const adminKeypair = keypairFromPrivateKey(env.adminExportedKey);
        const adminAddress = adminKeypair.getPublicKey().toSuiAddress();
        const playerAddress = playerCtx.address;
        await transferEve(playerCtx, playerAddress, adminAddress, adminKeypair);

    } catch (error) {
        handleError(error);
    }
}

main();