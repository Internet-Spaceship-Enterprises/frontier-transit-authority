import { Text, Strong, DataList, IconButton, Flex, Box, HoverCard } from "@radix-ui/themes";
import { JumpQuote } from "../queries/types";
import { formatTime } from "../utils/formatting";
import { InfoCircledIcon } from "@radix-ui/react-icons";


function formatEVE(amount: number) {
    return (amount / 1000000000).toFixed(9) + " EVE";
}

function Tooltip({ text }: { text: string }) {
    return (
        <HoverCard.Root>
            <HoverCard.Trigger>
                <IconButton size="1" variant="ghost" color="grass">
                    <InfoCircledIcon width="15" height="15" />
                </IconButton>
            </HoverCard.Trigger>
            <HoverCard.Content width="360px">
                <Text>{text}</Text>
            </HoverCard.Content>
        </HoverCard.Root>
    )
}

function DataListItem({ label, value, tooltip, strong }: { label: string, value: string, tooltip: string, strong?: boolean }) {
    return (
        <DataList.Item>
            <DataList.Label minWidth="88px">
                <Flex gap="2" direction="row" align="center">
                    <Text>
                        {
                            strong ? <Strong>{label}</Strong> : label
                        }</Text>
                    <Tooltip text={tooltip} />
                </Flex>
            </DataList.Label>
            <DataList.Value>
                <Text>{strong ? <Strong>{value}</Strong> : value}</Text>
            </DataList.Value>
        </DataList.Item >
    )
}

export function JumpQuoteTable({ quote }: { quote: JumpQuote }) {
    const scaled_source_gate_fee = formatEVE(quote.estimate.source_gate_fee * quote.estimate.scaling_factor / quote.estimate.precision_factor);
    const scaled_source_network_node_fee = formatEVE(quote.estimate.source_network_node_fee * quote.estimate.scaling_factor / quote.estimate.precision_factor);
    const scaled_destination_gate_fee = formatEVE(quote.estimate.destination_gate_fee * quote.estimate.scaling_factor / quote.estimate.precision_factor);
    const scaled_destination_network_node_fee = formatEVE(quote.estimate.destination_network_node_fee * quote.estimate.scaling_factor / quote.estimate.precision_factor);
    const total_base_fee = (quote.estimate.source_gate_fee + quote.estimate.source_network_node_fee + quote.estimate.destination_gate_fee + quote.estimate.destination_network_node_fee) * quote.estimate.scaling_factor / quote.estimate.precision_factor + quote.estimate.bounty_fee + quote.estimate.developer_fee;
    const blacklist_penalty = total_base_fee * (quote.estimate.penalty_factor - 100) / 100;
    const total_fee = total_base_fee + blacklist_penalty;
    return (
        <Box>
            <DataList.Root>
                <DataListItem label="Source Gate" value={scaled_source_gate_fee} tooltip="This is the fee charged by the operator of the source gate." />
                <DataListItem label="Source Network Node" value={scaled_source_network_node_fee} tooltip="This is the fee charged by the operator of the network node that powers the source gate." />
                <DataListItem label="Destination Gate" value={scaled_destination_gate_fee} tooltip="This is the fee charged by the operator of the destination gate." />
                <DataListItem label="Destination Network Node" value={scaled_destination_network_node_fee} tooltip="This is the fee charged by the operator of the network node that powers the destination gate." />
                <DataListItem label="Bounty Pool" value={formatEVE(quote.estimate.bounty_fee)} tooltip="This fee is contributed to the bounty pool to help keep the FTA safe." />
                <DataListItem label="Developer Pool" value={formatEVE(quote.estimate.developer_fee)} tooltip="This fee is contributed to the developer pool to fund FTA blockchain operations (gas)." />
                {
                    quote.estimate.penalty_factor > 100 ? (
                        <DataListItem label="Blacklist Penalty" value={formatEVE(blacklist_penalty)} tooltip="You are paying this penalty for aggressive actions against or near FTA infrastructure. It will be paid off over time." />
                    ) : null
                }
                <DataListItem label="Total Fee" strong={true} value={formatEVE(total_fee)} tooltip="This is the total cost of the Jump Permit." />
                <DataListItem label="Valid For" strong={true} value={formatTime(quote.estimate.validity_duration)} tooltip="This is the duration for which the Jump Permit will be valid once purchased." />
            </DataList.Root>
        </Box>
    );
}