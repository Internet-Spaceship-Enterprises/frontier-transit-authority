import { Box, Button, Tabs, Table, Spinner } from "@radix-ui/themes";
import { abbreviateAddress, CharacterInfo, AssemblyType, Assemblies } from "@evefrontier/dapp-kit";
import { useEffect, useState, useMemo } from "react";
import { getOwnedAssembliesByType } from "./queries/assemblies";
import { registerNetworkNodeTx } from "./transactions/register-network-node";
import { registerGateTx } from "./transactions/register-gate";
import { OwnedAssembliesByTypeResponse } from "./queries/assemblies";
import { useDAppKit, useCurrentAccount } from "@mysten/dapp-kit-react";
import {
    ColumnDef,
    flexRender,
    getCoreRowModel,
    getSortedRowModel,
    SortingState,
    useReactTable,
    Table as ReactTable,
} from '@tanstack/react-table'
import { Link2Icon } from "@radix-ui/react-icons";

type AssemblyTableProps = {
    assemblies: Record<string, AssemblyData> | null;
    sorting: SortingState;
    dAppKit: ReturnType<typeof useDAppKit>;
    account: ReturnType<typeof useCurrentAccount>;
    setSorting: (updater: SortingState | ((old: SortingState) => SortingState)) => void;
    registrationPendingById: Record<string, boolean>;
    setRegistrationPendingById: (updater: Record<string, boolean> | ((old: Record<string, boolean>) => Record<string, boolean>)) => void;
};

type AssemblyData = {
    owner: string;
    response: OwnedAssembliesByTypeResponse;
}

function renderTable(table: ReactTable<AssemblyData>) {
    return (
        <Table.Root>
            <Table.Header>
                {
                    table.getHeaderGroups().map((headerGroup) => (
                        <Table.Row key={headerGroup.id}>
                            {headerGroup.headers.map((header) => {
                                return (
                                    <Table.ColumnHeaderCell key={header.id} colSpan={header.colSpan}>
                                        {header.isPlaceholder ? null : (
                                            <div
                                                className={
                                                    header.column.getCanSort()
                                                        ? 'cursor-pointer select-none'
                                                        : ''
                                                }
                                                onClick={header.column.getToggleSortingHandler()}
                                                title={
                                                    header.column.getCanSort()
                                                        ? header.column.getNextSortingOrder() === 'asc'
                                                            ? 'Sort ascending'
                                                            : header.column.getNextSortingOrder() === 'desc'
                                                                ? 'Sort descending'
                                                                : 'Clear sort'
                                                        : undefined
                                                }
                                            >
                                                {flexRender(
                                                    header.column.columnDef.header,
                                                    header.getContext(),
                                                )}
                                                {{
                                                    asc: ' 🔼',
                                                    desc: ' 🔽',
                                                }[header.column.getIsSorted() as string] ?? null}
                                            </div>
                                        )}
                                    </Table.ColumnHeaderCell>
                                )
                            })}
                        </Table.Row>
                    ))}
            </Table.Header>
            <Table.Body>
                {table
                    .getRowModel()
                    .rows.slice(0, 10)
                    .map((row) => {
                        return (
                            <Table.Row key={row.id}>
                                {row.getVisibleCells().map((cell) => {
                                    return (
                                        <Table.Cell key={cell.id}>
                                            {flexRender(
                                                cell.column.columnDef.cell,
                                                cell.getContext(),
                                            )}
                                        </Table.Cell>
                                    )
                                })}
                            </Table.Row>
                        )
                    })}
            </Table.Body>
        </Table.Root>
    );
}

async function registerGate(gate: AssemblyData, props: AssemblyTableProps) {
    console.log("Registering gate:", gate);
    console.log("Props:", props);
    const gateAssembly = (gate.response.assembly as AssemblyType<Assemblies.SmartGate>);
    if (!gateAssembly.gate.destinationId) {
        console.error("Cannot register an unlinked gate");
        return;
    }
    console.log("Destination gate ID:", gateAssembly.gate.destinationId);
    const linkedGate = props.assemblies![gateAssembly.gate.destinationId];
    if (!linkedGate) {
        console.error("You do not own the linked gate with ID:", gateAssembly.gate.destinationId);
        return;
    }
    const linkedGateAssembly = (linkedGate.response.assembly as AssemblyType<Assemblies.SmartGate>);
    props.setRegistrationPendingById((prev) => ({
        ...prev,
        [gate.response.assembly.id]: true,
    }));
    await registerGateTx(
        props.dAppKit,
        gate.owner,
        gate.response.owner_cap.id,
        gateAssembly,
        999n, // TODO: popup to set fee
        props.account!.address,
        linkedGate.response.owner_cap.id,
        linkedGateAssembly,
        999n, // TODO: popup to set fee
        props.account!.address,
    );
    console.log("Gate registered!");
    props.setRegistrationPendingById((prev) => ({
        ...prev,
        [gate.response.assembly.id]: false,
    }));
}
function GateAssemblyTable(props: AssemblyTableProps) {
    const columns = useMemo<ColumnDef<AssemblyData>[]>(
        () => [
            {
                id: 'name',
                header: "Gate Name",
                accessorFn: (row) => (row.response.assembly as AssemblyType<Assemblies.SmartGate>).name,
            },
            {
                id: 'type',
                header: "Type",
                accessorFn: (row) => (row.response.assembly as AssemblyType<Assemblies.SmartGate>).typeId,
            },
            {
                id: 'id',
                header: "ID",
                accessorFn: (row) => abbreviateAddress((row.response.assembly as AssemblyType<Assemblies.SmartGate>).id),
            },
            {
                id: 'linkedTo',
                header: "Linked To",
                accessorFn: (row) => abbreviateAddress((row.response.assembly as AssemblyType<Assemblies.SmartGate>).gate.destinationId),
            },
            {
                id: 'transfer',
                header: "Transfer",
                accessorFn: (row) => row,
                cell: (row) => (
                    <Button onClick={() => registerGate(row.getValue() as AssemblyData, props)} disabled={props.registrationPendingById[(row.getValue() as AssemblyType<Assemblies>).id] ?? false}>
                        <Spinner loading={props.registrationPendingById[(row.getValue() as AssemblyType<Assemblies>).id] ?? false}>
                            <Link2Icon />
                        </Spinner>
                        Register
                    </Button>
                )
            },
        ],
        [],
    );
    const table = useReactTable({
        columns,
        data: Object.values(props.assemblies || {}),
        //debugTable: true,
        getCoreRowModel: getCoreRowModel(),
        getSortedRowModel: getSortedRowModel(), //client-side sorting
        onSortingChange: props.setSorting, //optionally control sorting state in your own scope for easy access
        state: {
            sorting: props.sorting,
        },
    });

    return renderTable(table);
}

async function registerNetworkNode(networkNode: AssemblyData, props: AssemblyTableProps) {
    console.log("Registering network node:", networkNode);
    props.setRegistrationPendingById((prev) => ({
        ...prev,
        [networkNode.response.assembly.id]: true,
    }));
    // await new Promise(resolve => setTimeout(resolve, 1000));
    // console.log("Wait done");
    await registerNetworkNodeTx(
        props.dAppKit,
        networkNode.owner,
        networkNode.response.owner_cap.id,
        networkNode.response.assembly.id,
        999n,
        props.account!.address
    );
    console.log("Network node registered!");
    props.setRegistrationPendingById((prev) => ({
        ...prev,
        [networkNode.response.assembly.id]: false,
    }));
}

function NetworkNodeAssemblyTable(props: AssemblyTableProps) {
    const columns = useMemo<ColumnDef<AssemblyData>[]>(
        () => [
            {
                id: 'name',
                header: "Network Node Name",
                accessorFn: (row) => (row.response.assembly as AssemblyType<Assemblies.NetworkNode>).name,
            },
            {
                id: 'id',
                header: "ID",
                accessorFn: (row) => abbreviateAddress((row.response.assembly as AssemblyType<Assemblies.NetworkNode>).id),
            },
            {
                id: 'online',
                header: "Online",
                accessorFn: (row) => (row.response.assembly as AssemblyType<Assemblies.NetworkNode>).networkNode.fuel.isBurning,
            },
            {
                id: 'register',
                header: "Register",
                accessorFn: (row) => row,
                cell: (row) => (
                    <Button onClick={() => registerNetworkNode(row.getValue() as AssemblyData, props)} disabled={props.registrationPendingById[(row.getValue() as AssemblyType<Assemblies>).id] ?? false}>
                        <Spinner loading={props.registrationPendingById[(row.getValue() as AssemblyType<Assemblies>).id] ?? false}>
                            <Link2Icon />
                        </Spinner>
                        Register
                    </Button>
                )

            },
        ],
        [],
    );
    const table = useReactTable({
        columns,
        data: Object.values(props.assemblies || {}),
        //debugTable: true,
        getCoreRowModel: getCoreRowModel(),
        getSortedRowModel: getSortedRowModel(), //client-side sorting
        onSortingChange: props.setSorting, //optionally control sorting state in your own scope for easy access
        state: {
            sorting: props.sorting,
        },
    });

    return renderTable(table);
}

type OperatorProps = {
    characters: CharacterInfo[];
};

export function Operator(props: OperatorProps) {
    const dAppKit = useDAppKit();
    const account = useCurrentAccount();
    const [networkNodes, setNetworkNodes] = useState<Record<string, AssemblyData> | null>(null);
    const [gates, setGates] = useState<Record<string, AssemblyData> | null>(null);

    const [gateSorting, setGateSorting] = useState<SortingState>([]);
    const [networkNodeSorting, setNetworkNodeSorting] = useState<SortingState>([]);
    const [registerPendingById, setRegisterPendingById] = useState<Record<string, boolean>>({});

    useEffect(() => {
        console.log("Loading Assemblies!");
        async function load() {
            let networkNodes: AssemblyData[] = [];
            let gates: AssemblyData[] = [];
            await Promise.all(props.characters.map(async char => {
                const networkNodesPromise = await getOwnedAssembliesByType(char.id, `network_node::NetworkNode`);
                const gatesPromise = await getOwnedAssembliesByType(char.id, "gate::Gate");
                networkNodes = networkNodes.concat(networkNodesPromise.map(response => ({
                    owner: char.id,
                    response,
                })));
                gates = gates.concat(gatesPromise.map(response => ({
                    owner: char.id,
                    response,
                })));
            }));
            let networkNodesMap: Record<string, AssemblyData> = {};
            networkNodes.forEach(networkNode => {
                networkNodesMap[networkNode.response.assembly.id] = networkNode;
            });
            console.log("Setting network nodes:", networkNodesMap);
            setNetworkNodes(networkNodesMap);

            let gatesMap: Record<string, AssemblyData> = {};
            gates.forEach(gate => {
                gatesMap[gate.response.assembly.id] = gate;
            });
            console.log("Setting gates:", gatesMap);
            setGates(gatesMap);
        };
        load();
    }, [props.characters]);

    return (
        <Tabs.Root defaultValue="gates">
            <Tabs.List>
                <Tabs.Trigger value="network-nodes">Network Nodes</Tabs.Trigger>
                <Tabs.Trigger value="gates">Gates</Tabs.Trigger>
            </Tabs.List>

            <Box pt="3">
                <Tabs.Content value="network-nodes">
                    <NetworkNodeAssemblyTable assemblies={networkNodes} sorting={networkNodeSorting} setSorting={setNetworkNodeSorting} registrationPendingById={registerPendingById} setRegistrationPendingById={setRegisterPendingById} dAppKit={dAppKit} account={account} />
                </Tabs.Content>

                <Tabs.Content value="gates">
                    <GateAssemblyTable assemblies={gates} sorting={gateSorting} setSorting={setGateSorting} registrationPendingById={registerPendingById} setRegistrationPendingById={setRegisterPendingById} dAppKit={dAppKit} account={account} />
                </Tabs.Content>
            </Box>
        </Tabs.Root>
    );
}
