import { Button, Text, Dialog, Flex, Spinner, Box } from "@radix-ui/themes";
import { useCurrentAccount, useDAppKit } from "@mysten/dapp-kit-react";
import { getJumpQuote } from "./transactions/get-jump-quote";
import { CharacterInfo, AssemblyType, Assemblies } from "@evefrontier/dapp-kit";
import { useState, useEffect } from "react";
import { getGateById } from "./queries/assemblies";
import { JumpQuote, JumpPermit } from "./queries/types";
import { Dispatch, SetStateAction } from "react";
import { getJumpPermit } from "./transactions/get-jump-permit";
import { JumpPermitDisplay } from "./components/jump-permit";
import { RocketIcon, CheckCircledIcon } from "@radix-ui/react-icons";
import { JumpQuoteTable } from "./components/jump-quote";
import { getSolarSystem, SolarSystemResponse } from "./queries/api/solar-system";
import { useFTA } from "./hooks/useFTA";
import { Loading } from "./components/loading";

const localStorageKeyJumpPermit = "jump-permit";

async function prepareQuote(dAppKit: ReturnType<typeof useDAppKit>, setQuoteLoading: Dispatch<SetStateAction<boolean>>, setQuote: Dispatch<SetStateAction<JumpQuote | null>>, walletAddress: string, character: CharacterInfo, source_gate_id: string, destination_gate_id: string) {
    try {
        setQuoteLoading(true);
        const jumpQuote = await getJumpQuote(
            dAppKit,
            walletAddress,
            character.id,
            source_gate_id,
            destination_gate_id,
        );
        console.log("Jump quote:", jumpQuote);
        setQuote(jumpQuote);
    } finally {
        setQuoteLoading(false);
    }
}

async function buyPermit(dAppKit: ReturnType<typeof useDAppKit>, quote: JumpQuote, setPermitLoading: Dispatch<SetStateAction<boolean>>, setQuote: Dispatch<SetStateAction<JumpQuote | null>>, setPermit: Dispatch<SetStateAction<JumpPermit | null>>) {
    try {
        setPermitLoading(true);
        const sourceGatePromise = getGateById(quote.estimate.source_gate_id);
        const destinationGatePromise = getGateById(quote.estimate.destination_gate_id);
        const sourceGate = await sourceGatePromise;
        const destinationGate = await destinationGatePromise;
        if (!sourceGate) {
            throw new Error(`Unable to load source gate with ID ${quote.estimate.source_gate_id}`);
        }
        if (!destinationGate) {
            throw new Error(`Unable to load destination gate with ID ${quote.estimate.destination_gate_id}`);
        }
        const permit = await getJumpPermit(dAppKit, quote, sourceGate, destinationGate);
        localStorage.setItem(localStorageKeyJumpPermit, JSON.stringify(permit));
        setPermit(permit);
        setQuote(null);
        setPermitLoading(false);
    } finally {
        setPermitLoading(false);
    }
}

type TravelerProps = {
    character: CharacterInfo;
};

export function Traveler(props: TravelerProps) {
    const dAppKit = useDAppKit();
    const account = useCurrentAccount();
    const fta = useFTA();
    const [loading, setLoading] = useState<boolean>(true);
    const [quoteLoading, setQuoteLoading] = useState<boolean>(false);
    const [permitLoading, setPermitLoading] = useState<boolean>(false);
    const [gate, setGate] = useState<AssemblyType<Assemblies.SmartGate> | null>(null);
    const [quote, setQuote] = useState<JumpQuote | null>(null);
    const [destinationSystem, setDestinationSystem] = useState<SolarSystemResponse | null>(null);

    // Try loading the permit from local storage
    // TODO: replace this with a GraphQL query so it disappears if the permit is used
    const existingPermitJson = localStorage.getItem(localStorageKeyJumpPermit);
    let existingPermit: JumpPermit | null = existingPermitJson ? JSON.parse(existingPermitJson) : null;
    if (existingPermit && existingPermit.expires_at_timestamp_ms < Date.now()) {
        existingPermit = null;
        localStorage.removeItem(localStorageKeyJumpPermit);
    }
    const [permit, setPermit] = useState<JumpPermit | null>(existingPermit);

    if (!fta.assemblyId) {
        return (
            <Box alignSelf="center" justifySelf="center">
                <Text>Out-of-game Traveler mode coming soon!</Text>
            </Box>
        )
    }
    useEffect(() => {
        async function load() {
            const gate = await getGateById(fta.assemblyId!);
            if (!gate!.gate.destinationId) {
                throw new Error("Gate is not linked");
            }
            setDestinationSystem(await getSolarSystem(fta.locations![gate!.gate.destinationId!].solarsystem));
            setGate(gate);
            setLoading(false);
        };
        load();
    }, [props.character]);

    if (loading) {
        return (
            <Loading />
        )
    }

    if (permit) {
        return (
            <JumpPermitDisplay permit={permit} setPermit={setPermit} />
        )
    }

    if (!quote) {
        return (
            <Flex direction="column" p="4" gap="2" align="center">
                <Text>Traveling to: {destinationSystem?.name}</Text>
                <Button disabled={quoteLoading} onClick={() => { prepareQuote(dAppKit, setQuoteLoading, setQuote, account?.address!, props.character, gate!.id, gate!.gate.destinationId!) }}>
                    <Spinner loading={quoteLoading}>
                        <CheckCircledIcon />
                    </Spinner>
                    Get Quote
                </Button>
            </Flex>
        )
    }

    return (
        <Dialog.Root open={true}>
            <Dialog.Content maxWidth="340px">
                <Dialog.Title>Jump Quote</Dialog.Title>
                <Dialog.Description size="2" mb="4">

                </Dialog.Description>

                <Flex direction="column" gap="3">
                    <JumpQuoteTable quote={quote} />
                </Flex>

                <Flex gap="3" mt="4" justify="end">
                    <Dialog.Close>
                        <Button variant="soft" color="gray" onClick={() => setQuote(null)}>
                            Cancel
                        </Button>
                    </Dialog.Close>
                    <Dialog.Close>
                        <Button disabled={permitLoading} autoFocus onClick={() => buyPermit(dAppKit, quote, setPermitLoading, setQuote, setPermit)}>
                            <Spinner loading={permitLoading}>
                                <RocketIcon />
                            </Spinner>
                            Purchase!</Button>
                    </Dialog.Close>
                </Flex>
            </Dialog.Content>
        </Dialog.Root>
    );
}
