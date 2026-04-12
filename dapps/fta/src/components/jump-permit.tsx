import { Text, Flex, Strong } from "@radix-ui/themes";
import { useState, useEffect, useMemo } from "react";
import { JumpPermit } from "../graphql/types";
import { Dispatch, SetStateAction } from "react";

function timeRemaining(permit: JumpPermit) {
    const expiresAt = Number(permit.expires_at_timestamp_ms);
    const now = Date.now();
    return Math.max(0, expiresAt - now);
}

function formatRemaining(ms: number) {
    const totalSeconds = Math.max(0, Math.floor(ms / 1000));
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;
    return {
        hours,
        minutes,
        seconds,
        text: [
            String(hours).padStart(2, "0"),
            String(minutes).padStart(2, "0"),
            String(seconds).padStart(2, "0"),
        ].join(":"),
    };
}

type JumpPermitProps = {
    permit: JumpPermit;
    setPermit: Dispatch<SetStateAction<JumpPermit | null>>,
};

export function JumpPermitDisplay(props: JumpPermitProps) {
    const [remainingMs, setRemainingMs] = useState(timeRemaining(props.permit));
    useEffect(() => {
        const update = () => {
            const remaining = timeRemaining(props.permit);
            if (remaining <= 0) {
                props.setPermit(null);
                return;
            }
            setRemainingMs(remaining);
        };
        // Update once now
        update();
        // Now update every second
        const intervalId = window.setInterval(update, 1000);
        return () => {
            window.clearInterval(intervalId);
        };
    }, [props.permit]);
    const remaining = useMemo(() => formatRemaining(remainingMs), [remainingMs]);

    return (
        <Flex direction="column" gap="2" align="center">
            <Text>You have a valid permit for this gate!</Text>
            <Flex direction="column" gap="0" align="center">
                <Text>Time Remaining: </Text>
                <Text><Strong>{remaining.text}</Strong></Text>
            </Flex >
        </Flex >
    )
}
