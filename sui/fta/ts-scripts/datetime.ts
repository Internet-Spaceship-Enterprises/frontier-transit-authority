import "dotenv/config";
import { Transaction } from "@mysten/sui/transactions";
import { bcs } from '@mysten/sui/bcs';
import { FTA_PACKAGE_ID } from "./config";
import {
    getEnvConfig,
    handleError,
    initializeContext,
    requireEnv,
} from "../../../ts-scripts/utils/helper";

async function datetime(
    ctx: ReturnType<typeof initializeContext>,
) {
    const { client, keypair, config, address } = ctx;
    let tx = new Transaction();

    tx.moveCall({
        target: `${FTA_PACKAGE_ID}::datetime::datetime_from_timestamp_ms`,
        arguments: [
            tx.pure.u64(1772615345000),
        ],
    });

    tx.setSender(address);

    // Simulate it and request command return values:
    const sim = await client.core.simulateTransaction({
        transaction: await tx.build({ client }),
        include: {
            commandResults: true,
        },
    });

    // First command, first returned value:
    const output = sim.commandResults?.[0]?.returnValues?.[0];
    if (!output) {
        throw new Error('No string return value found');
    }

    // Decode std::string::String from BCS:
    const result = bcs.String.parse(output.bcs);

    console.log(result);
}

async function main() {
    try {
        const env = getEnvConfig();
        const playerKey = requireEnv("PLAYER_B_PRIVATE_KEY");
        const playerCtx = initializeContext(env.network, playerKey);
        await datetime(playerCtx);

    } catch (error) {
        handleError(error);
    }
}

main();