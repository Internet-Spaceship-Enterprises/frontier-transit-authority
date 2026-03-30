module fta::transfer;

use fta::fta::FrontierTransitAuthority;
use fta::gate_record;
use sui::clock::Clock;
use world::access::{OwnerCap, ReturnOwnerCapReceipt};
use world::character::Character;
use world::energy::EnergyConfig;
use world::gate::Gate;
use world::network_node::NetworkNode;

#[error(code = 0)]
const EGateOwnerCapMismatch: vector<u8> = b"OwnerCap<Gate> does not belong to this Gate";
#[error(code = 1)]
const ENetworkNodeOwnerCapMismatch: vector<u8> =
    b"OwnerCap<NetworkNode> does not belong to this NetworkNode";
#[error(code = 2)]
const EGatesNotLinked: vector<u8> = b"The two gates being transferred must be linked";
#[error(code = 3)]
const ETransferNetworkNodeAsWell: vector<u8> =
    b"If the gate is connected to a network node that is not already owned by FTA, then it must be provided (use the `transfer_gate_and_network_node` function)";
#[error(code = 4)]
const ENoNetworkNodeProvided: vector<u8> =
    b"If the gate is connected to a network node, then the network node must be provided";

public struct GateTransferReceipt {
    gate_id: ID,
    gate_owner_cap_id: ID,
    network_node_id: Option<ID>,
    network_node_owner_cap_id: Option<ID>,
}

public fun transfer_gate_and_network_node(
    gate_network: &mut FrontierTransitAuthority,
    gate_a_receipt_opt: &Option<GateTransferReceipt>,
    current_owner: &mut Character,
    gate: &mut Gate,
    gate_owner_cap: OwnerCap<Gate>,
    gate_owner_cap_receipt: ReturnOwnerCapReceipt,
    network_node: &mut NetworkNode,
    network_node_owner_cap: OwnerCap<NetworkNode>,
    network_node_owner_cap_receipt: ReturnOwnerCapReceipt,
    jump_fee: u64,
    energy_config: &EnergyConfig,
    clock: &Clock,
    ctx: &mut TxContext,
): Option<GateTransferReceipt> {
    let nn_id = object::id(network_node);
    let nn_owner_cap_id = object::id(&network_node_owner_cap);
    // Run some access checks to ensure this is the right owner cap for this network node
    assert!(network_node_owner_cap.is_authorized(nn_id), ENetworkNodeOwnerCapMismatch);
    assert!(network_node.owner_cap_id() == nn_owner_cap_id, ENetworkNodeOwnerCapMismatch);

    // If the gate is connected to a network node and is online, offline it
    if (gate.is_online()) {
        gate.offline(network_node, energy_config, &gate_owner_cap);
    };

    // Do the gate transfer
    let res = transfer_gate(
        gate_network,
        gate_a_receipt_opt,
        current_owner,
        gate,
        gate_owner_cap,
        gate_owner_cap_receipt,
        option::some(nn_id),
        option::some(nn_owner_cap_id),
        jump_fee,
        clock,
        ctx,
    );

    // Transfer the network node ownership to FTA
    network_node_owner_cap.transfer_owner_cap_with_receipt(
        network_node_owner_cap_receipt,
        object::id_address(gate_network),
        ctx,
    );

    // Put the record in the table
    gate_network.add_network_node_record(
        fta::network_node_record::new(
            clock.timestamp_ms(),
            object::id(current_owner),
            ctx.sender(),
            object::id(network_node),
            nn_owner_cap_id,
        ),
    );

    // Return the result of the transfer
    res
}

public fun transfer_gate_only(
    gate_network: &mut FrontierTransitAuthority,
    gate_receipt_opt: &Option<GateTransferReceipt>,
    current_owner: &mut Character,
    gate: &mut Gate,
    gate_owner_cap: OwnerCap<Gate>,
    gate_owner_cap_receipt: ReturnOwnerCapReceipt,
    network_node: &mut Option<NetworkNode>,
    jump_fee: u64,
    energy_config: &EnergyConfig,
    clock: &Clock,
    ctx: &mut TxContext,
): Option<GateTransferReceipt> {
    let mut network_node_id_opt = option::none<ID>();
    let mut network_node_owner_cap_id_opt = option::none<ID>();
    let energy_source_id = gate.energy_source_id();
    if (energy_source_id.is_some()) {
        let network_node_id = *energy_source_id.borrow();
        // If the gate is connected to a network node, assert that we already own it.
        // Otherwise, they need to call the function that transfers NetworkNode ownership as well.
        assert!(
            gate_network.network_node_table().contains(network_node_id),
            ETransferNetworkNodeAsWell,
        );
        // If the gate is connected to a network node, assert that a NetworkNode object was provided
        assert!(network_node.is_some(), ENoNetworkNodeProvided);

        network_node_id_opt = option::some(network_node_id);
        network_node_owner_cap_id_opt =
            option::some(
                *gate_network
                    .network_node_table()
                    .borrow(network_node_id)
                    .network_node_owner_cap_id(),
            );

        // If the gate is connected to a network node and is online, offline it
        if (gate.is_online()) {
            gate.offline(network_node.borrow_mut(), energy_config, &gate_owner_cap);
        };
    };

    transfer_gate(
        gate_network,
        gate_receipt_opt,
        current_owner,
        gate,
        gate_owner_cap,
        gate_owner_cap_receipt,
        network_node_id_opt,
        network_node_owner_cap_id_opt,
        jump_fee,
        clock,
        ctx,
    )
}

fun transfer_gate(
    gate_network: &mut FrontierTransitAuthority,
    gate_a_receipt_opt: &Option<GateTransferReceipt>,
    current_owner: &Character,
    gate: &mut Gate,
    gate_owner_cap: OwnerCap<Gate>,
    gate_owner_cap_receipt: ReturnOwnerCapReceipt,
    network_node_id: Option<ID>,
    network_node_owner_cap_id: Option<ID>,
    jump_fee: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): Option<GateTransferReceipt> {
    // Ensure the gate is linked, since we can't link it after it's been transferred
    assert!(!gate.linked_gate_id().is_none(), EGatesNotLinked);

    let gate_id = object::id(gate);
    let gate_owner_cap_id = object::id(&gate_owner_cap);
    // Run some access checks to ensure this is the right owner cap for this gate
    assert!(gate_owner_cap.is_authorized(gate_id), EGateOwnerCapMismatch);
    assert!(gate.owner_cap_id() == gate_owner_cap_id, EGateOwnerCapMismatch);

    // Use the borrowed owner cap to prepare the gate
    prepare_gate(
        gate,
        &gate_owner_cap,
        ctx,
    );

    // Transfer the gate ownership to FTA
    gate_owner_cap.transfer_owner_cap_with_receipt(
        gate_owner_cap_receipt,
        object::id_address(gate_network),
        ctx,
    );

    // Record the important values
    let record = gate_record::new(
        clock.timestamp_ms(),
        object::id(current_owner),
        ctx.sender(),
        // Gate B values are from this call
        gate_id,
        gate_owner_cap_id,
        network_node_id,
        network_node_owner_cap_id,
        jump_fee,
        clock,
        ctx,
    );
    // Put the record in the table using a unique hash for the pair
    gate_network.add_gate_record(record);

    // Check if this is the second transfer
    if (gate_a_receipt_opt.is_some()) {
        let gate_a_receipt = gate_a_receipt_opt.borrow();
        let linked_gate_id_opt = gate.linked_gate_id();
        assert!(
            linked_gate_id_opt.is_some() && linked_gate_id_opt.borrow() == gate_a_receipt.gate_id,
            EGatesNotLinked,
        );

        // Consume the receipt
        let _ = gate_a_receipt;

        // If a receipt was passed in, then this is the second transfer of two,
        // so do not return a receipt.
        option::none()
    } else {
        // If no receipt was passed in, then this is the first transfer of two,
        // so return the receipt that must be consumed.
        option::some(GateTransferReceipt {
            gate_id: gate_id,
            gate_owner_cap_id: gate_owner_cap_id,
            network_node_id: network_node_id,
            network_node_owner_cap_id,
        })
    }
}

/// Prepares a gate for FTA operation
fun prepare_gate(gate: &mut Gate, gate_owner_cap: &OwnerCap<Gate>, _ctx: &mut TxContext) {
    // TODO: set metadata name using the system/location
    gate.update_metadata_name(gate_owner_cap, b"Frontier Transit Authority".to_string());
    // TODO: configure the authorization extension
}
