import { Flex, Button, Text, TextField } from "@radix-ui/themes";
import { MagnifyingGlassIcon } from "@radix-ui/react-icons";
import { CharacterInfo, AssemblyType, Assemblies } from "@evefrontier/dapp-kit";
import { useEffect, useState } from "react";
import { getOwnedAssembliesByType } from "./queries/assemblies";
import { registerNetworkNodeTx } from "./transactions/register-network-node";
import { registerGateTx } from "./transactions/register-gate";
import { OwnedAssembliesByTypeResponse } from "./queries/assemblies";
import { useDAppKit, useCurrentAccount } from "@mysten/dapp-kit-react";
// import {
//     SortingState,
// } from '@tanstack/react-table'

type AssemblyTableProps = {
    assemblies: Record<string, AssemblyData> | null;
    //sorting: SortingState;
    dAppKit: ReturnType<typeof useDAppKit>;
    account: ReturnType<typeof useCurrentAccount>;
    //setSorting: (updater: SortingState | ((old: SortingState) => SortingState)) => void;
    //registrationPendingById: Record<string, boolean>;
    //setRegistrationPendingById: (updater: Record<string, boolean> | ((old: Record<string, boolean>) => Record<string, boolean>)) => void;
};

type AssemblyData = {
    owner: string;
    response: OwnedAssembliesByTypeResponse;
}

// type AssemblyRow = {
//     owner: string;
//     response: OwnedAssembliesByTypeResponse;
//     assemblies: Record<string, AssemblyData> | null;
// }

// function renderTable(table: ReactTable<AssemblyData>) {
//     return (
//         <Table.Root>
//             <Table.Header>
//                 {
//                     table.getHeaderGroups().map((headerGroup) => (
//                         <Table.Row key={headerGroup.id}>
//                             {headerGroup.headers.map((header) => {
//                                 return (
//                                     <Table.ColumnHeaderCell key={header.id} colSpan={header.colSpan}>
//                                         {header.isPlaceholder ? null : (
//                                             <div
//                                                 className={
//                                                     header.column.getCanSort()
//                                                         ? 'cursor-pointer select-none'
//                                                         : ''
//                                                 }
//                                                 onClick={header.column.getToggleSortingHandler()}
//                                                 title={
//                                                     header.column.getCanSort()
//                                                         ? header.column.getNextSortingOrder() === 'asc'
//                                                             ? 'Sort ascending'
//                                                             : header.column.getNextSortingOrder() === 'desc'
//                                                                 ? 'Sort descending'
//                                                                 : 'Clear sort'
//                                                         : undefined
//                                                 }
//                                             >
//                                                 {flexRender(
//                                                     header.column.columnDef.header,
//                                                     header.getContext(),
//                                                 )}
//                                                 {{
//                                                     asc: ' 🔼',
//                                                     desc: ' 🔽',
//                                                 }[header.column.getIsSorted() as string] ?? null}
//                                             </div>
//                                         )}
//                                     </Table.ColumnHeaderCell>
//                                 )
//                             })}
//                         </Table.Row>
//                     ))}
//             </Table.Header>
//             <Table.Body>
//                 {table
//                     .getRowModel()
//                     .rows.slice(0, 10)
//                     .map((row) => {
//                         return (
//                             <Table.Row key={row.id}>
//                                 {row.getVisibleCells().map((cell) => {
//                                     return (
//                                         <Table.Cell key={cell.id}>
//                                             {flexRender(
//                                                 cell.column.columnDef.cell,
//                                                 cell.getContext(),
//                                             )}
//                                         </Table.Cell>
//                                     )
//                                 })}
//                             </Table.Row>
//                         )
//                     })}
//             </Table.Body>
//         </Table.Root>
//     );
// }

async function registerGate(gate: AssemblyData, linkedGate: AssemblyData, props: AssemblyTableProps) {
    console.log("Registering gate:", gate);
    console.log("Props:", props);
    const gateAssembly = gate.response.assembly as AssemblyType<Assemblies.SmartGate>;
    const linkedGateAssembly = linkedGate.response.assembly as AssemblyType<Assemblies.SmartGate>;
    // const gateAssembly = (gate.response.assembly as AssemblyType<Assemblies.SmartGate>);
    // if (!gateAssembly.gate.destinationId) {
    //     console.error("Cannot register an unlinked gate");
    //     return;
    // }
    // console.log("Destination gate ID:", gateAssembly.gate.destinationId);
    // const linkedGate = gate.assemblies![gateAssembly.gate.destinationId];
    if (!linkedGate) {
        console.error("You do not own the linked gate with ID:", gateAssembly.gate.destinationId);
        return;
    }
    //const linkedGateAssembly = (linkedGate.response.assembly as AssemblyType<Assemblies.SmartGate>);
    // props.setRegistrationPendingById((prev) => ({
    //     ...prev,
    //     [gate.response.assembly.id]: true,
    // }));
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
    // props.setRegistrationPendingById((prev) => ({
    //     ...prev,
    //     [gate.response.assembly.id]: false,
    // }));
}
// function GateAssemblyTable(props: AssemblyTableProps) {
//     const columns = useMemo<ColumnDef<AssemblyData>[]>(
//         () => [
//             {
//                 id: 'name',
//                 header: "Gate Name",
//                 accessorFn: (row) => (row.response.assembly as AssemblyType<Assemblies.SmartGate>).name,
//             },
//             {
//                 id: 'type',
//                 header: "Type",
//                 accessorFn: (row) => (row.response.assembly as AssemblyType<Assemblies.SmartGate>).typeId,
//             },
//             {
//                 id: 'id',
//                 header: "ID",
//                 accessorFn: (row) => abbreviateAddress((row.response.assembly as AssemblyType<Assemblies.SmartGate>).id),
//             },
//             {
//                 id: 'linkedTo',
//                 header: "Linked To",
//                 accessorFn: (row) => abbreviateAddress((row.response.assembly as AssemblyType<Assemblies.SmartGate>).gate.destinationId),
//             },
//             {
//                 id: 'transfer',
//                 header: "Transfer",
//                 accessorFn: (row) => row,
//                 cell: (row) => (
//                     <Button onClick={() => registerGate(row.getValue() as AssemblyRow, props)} disabled={props.registrationPendingById[(row.getValue() as AssemblyRow).response.assembly.id] ?? false}>
//                         <Spinner loading={props.registrationPendingById[(row.getValue() as AssemblyRow).response.assembly.id] ?? false}>
//                             <Link2Icon />
//                         </Spinner>
//                         Register
//                     </Button>
//                 )
//             },
//         ],
//         [],
//     );
//     const table = useReactTable({
//         columns,
//         data: Object.values(props.assemblies || {}).map(assemblyData => ({
//             ...assemblyData,
//             assemblies: props.assemblies, // Pass down the full assemblies map so we can look up linked gates when registering
//         })),
//         //debugTable: true,
//         getCoreRowModel: getCoreRowModel(),
//         getSortedRowModel: getSortedRowModel(), //client-side sorting
//         onSortingChange: props.setSorting, //optionally control sorting state in your own scope for easy access
//         state: {
//             sorting: props.sorting,
//         },
//     });

//     return renderTable(table);
// }

async function registerNetworkNode(networkNode: AssemblyData, props: AssemblyTableProps) {
    console.log("Registering network node:", networkNode);
    // props.setRegistrationPendingById((prev) => ({
    //     ...prev,
    //     [networkNode.response.assembly.id]: true,
    // }));
    await registerNetworkNodeTx(
        props.dAppKit,
        networkNode.owner,
        networkNode.response.owner_cap.id,
        networkNode.response.assembly.id,
        999n,
        props.account!.address
    );
    console.log("Network node registered!");
    // props.setRegistrationPendingById((prev) => ({
    //     ...prev,
    //     [networkNode.response.assembly.id]: false,
    // }));
}

// function NetworkNodeAssemblyTable(props: AssemblyTableProps) {
//     const columns = useMemo<ColumnDef<AssemblyData>[]>(
//         () => [
//             {
//                 id: 'name',
//                 header: "Network Node Name",
//                 accessorFn: (row) => (row.response.assembly as AssemblyType<Assemblies.NetworkNode>).name,
//             },
//             {
//                 id: 'id',
//                 header: "ID",
//                 accessorFn: (row) => abbreviateAddress((row.response.assembly as AssemblyType<Assemblies.NetworkNode>).id),
//             },
//             {
//                 id: 'online',
//                 header: "Online",
//                 accessorFn: (row) => (row.response.assembly as AssemblyType<Assemblies.NetworkNode>).networkNode.fuel.isBurning,
//             },
//             {
//                 id: 'register',
//                 header: "Register",
//                 accessorFn: (row) => row,
//                 cell: (row) => (
//                     <Button onClick={() => registerNetworkNode(row.getValue() as AssemblyRow, props)} disabled={props.registrationPendingById[(row.getValue() as AssemblyRow).response.assembly.id] ?? false}>
//                         <Spinner loading={props.registrationPendingById[(row.getValue() as AssemblyRow).response.assembly.id] ?? false}>
//                             <Link2Icon />
//                         </Spinner>
//                         Register
//                     </Button>
//                 )

//             },
//         ],
//         [],
//     );
//     const table = useReactTable({
//         columns,
//         data: Object.values(props.assemblies || {}).map(assemblyData => ({
//             ...assemblyData,
//             assemblies: props.assemblies, // Pass down the full assemblies map so we can look up linked gates when registering
//         })),
//         //debugTable: true,
//         getCoreRowModel: getCoreRowModel(),
//         getSortedRowModel: getSortedRowModel(), //client-side sorting
//         onSortingChange: props.setSorting, //optionally control sorting state in your own scope for easy access
//         state: {
//             sorting: props.sorting,
//         },
//     });

//     return renderTable(table);
// }

type OperatorProps = {
    character: CharacterInfo;
};

export function Operator(props: OperatorProps) {
    const dAppKit = useDAppKit();
    const account = useCurrentAccount();
    const [networkNodes, setNetworkNodes] = useState<Record<string, AssemblyData> | null>(null);
    const [gates, setGates] = useState<Record<string, AssemblyData> | null>(null);

    // const [gateSorting, setGateSorting] = useState<SortingState>([]);
    // const [networkNodeSorting, setNetworkNodeSorting] = useState<SortingState>([]);
    // const [registerPendingById, setRegisterPendingById] = useState<Record<string, boolean>>({});
    const [assemblyId, setAssemblyId] = useState<string>("");

    useEffect(() => {
        console.log("Loading Assemblies!");
        async function load() {
            let networkNodesArray: AssemblyData[] = [];
            let gatesArray: AssemblyData[] = [];
            const networkNodesPromise = await getOwnedAssembliesByType(props.character.id, `network_node::NetworkNode`);
            const gatesPromise = await getOwnedAssembliesByType(props.character.id, "gate::Gate");
            networkNodesArray = networkNodesArray.concat(networkNodesPromise.map(response => ({
                owner: props.character.id,
                response,
                assemblies: networkNodes,
            })));
            gatesArray = gatesArray.concat(gatesPromise.map(response => ({
                owner: props.character.id,
                response,
                assemblies: gates,
            })));
            let networkNodesMap: Record<string, AssemblyData> = {};
            networkNodesArray.forEach(networkNode => {
                networkNodesMap[networkNode.response.assembly.id] = networkNode;
            });
            // Object.entries(networkNodesMap).forEach(([id, _]) => {
            //     networkNodesMap[id].assemblies = networkNodesMap;
            // })
            console.log("Setting network nodes:", networkNodesMap);
            setNetworkNodes(networkNodesMap);

            let gatesMap: Record<string, AssemblyData> = {};
            gatesArray.forEach(gate => {
                gatesMap[gate.response.assembly.id] = gate;
            });
            // Object.entries(gatesMap).forEach(([id, _]) => {
            //     gatesMap[id].assemblies = gatesMap;
            // })
            console.log("Setting gates:", gatesMap);
            setGates(gatesMap);
        };
        load();
    }, [props.character]);

    return (
        <Flex direction="column" gap="3">
            <Text>Register Assembly:</Text>
            <TextField.Root onChange={(e) => setAssemblyId(e.target.value)} value={assemblyId} placeholder="Assembly ID: 0x123...">
                <TextField.Slot>
                    <MagnifyingGlassIcon height="16" width="16" />
                </TextField.Slot>
            </TextField.Root>
            <Button onClick={async () => {
                const foundNetworkNode = networkNodes ? networkNodes[assemblyId] : null;
                if (foundNetworkNode) {
                    console.log("Found network node with ID:", assemblyId, foundNetworkNode);
                    await registerNetworkNode(foundNetworkNode, { assemblies: gates, dAppKit, account });
                    return;
                } else {
                    const foundGate = gates ? gates[assemblyId] : null;
                    if (foundGate) {
                        console.log("Found gate with ID:", assemblyId, foundGate);
                        const assembly = foundGate.response.assembly as AssemblyType<Assemblies.SmartGate>;
                        if (!assembly.gate.destinationId) {
                            console.error("Gate with ID:", assemblyId, "is not linked to any destination gate. Please link it before registering.");
                            return;
                        }
                        const linkedGate = gates ? gates[assembly.gate.destinationId] : null;
                        if (!linkedGate) {
                            console.error("You do not own the linked gate with ID:", assembly.gate.destinationId, ". Please acquire it before registering.");
                            return;
                        }
                        await registerGate(foundGate, linkedGate, { assemblies: gates, dAppKit, account });
                        return;
                    } else {
                        console.error("No gate found with ID:", assemblyId);
                    }
                    console.error("No network node found with ID:", assemblyId);
                }
            }
            }>Register</Button>
        </Flex>
    );
}
