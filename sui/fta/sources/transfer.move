module fta::transfer;

use fta::access;
use fta::fta::{FrontierTransitAuthority, DeveloperCap};
use fta::gate_record;
use fta::network_node_record;
use sui::clock::Clock;
use sui::transfer::Receiving;
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
const EWrongNetworkNode: vector<u8> =
    b"The NetworkNode provided is not the correct one for this Gate";
#[error(code = 4)]
const ENoNetworkNodeOwnerCapProvided: vector<u8> =
    b"If the gate is connected to a network node that is not already owned by FTA, then the network node's OwnerCap and Receipt must be provided";
#[error(code = 5)]
const EGateHasNoNetworkNode: vector<u8> =
    b"A gate cannot be transferred to FTA if it is not connected to a network node";
#[error(code = 6)]
const EDifferentNetworkNodes: vector<u8> =
    b"If using the `transfer_gate_pair_same_network_node` function, both gates must be linked to the same network node";

fun transfer_gate_pair_validation(gate_1: &Gate, gate_2: &Gate) {
    // Ensure the gates are bi-directionally linked
    assert!(
        gate_1.linked_gate_id().is_some() && gate_1.linked_gate_id().borrow() == object::id(gate_2),
        EGatesNotLinked,
    );
    assert!(
        gate_2.linked_gate_id().is_some() && gate_2.linked_gate_id().borrow() == object::id(gate_1),
        EGatesNotLinked,
    );

    // Ensure the gates both have a network node
    assert!(
        gate_1.energy_source_id().is_some() && gate_2.energy_source_id().is_some(),
        EGateHasNoNetworkNode,
    );
}

fun transfer_gate(
    fta: &mut FrontierTransitAuthority,
    current_owner: &Character,
    gate: &mut Gate,
    gate_owner_cap: OwnerCap<Gate>,
    gate_owner_cap_receipt: ReturnOwnerCapReceipt,
    network_node: &mut NetworkNode,
    network_node_owner_cap: &Option<OwnerCap<NetworkNode>>,
    network_node_owner_cap_receipt: &Option<ReturnOwnerCapReceipt>,
    jump_fee: u64,
    energy_config: &EnergyConfig,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // Ensure the correct network node was provided
    assert!(gate.energy_source_id().borrow() == object::id(network_node), EWrongNetworkNode);

    // Ensure the gate owner cap provided is the right one for the gate
    assert!(gate_owner_cap.is_authorized(object::id(gate)), EGateOwnerCapMismatch);
    assert!(gate.owner_cap_id() == object::id(&gate_owner_cap), EGateOwnerCapMismatch);

    // Ensure the gate is linked, since we can't link it after it's been transferred
    assert!(!gate.linked_gate_id().is_none(), EGatesNotLinked);

    // Ensure that either the owner cap was provided or we already own it
    assert!(
        fta.gate_network_node_registered(gate) || (network_node_owner_cap.is_some() && network_node_owner_cap_receipt.is_some()),
        ENoNetworkNodeOwnerCapProvided,
    );
    // Ensure the network node owner cap provided is the right one for the network node
    assert!(
        network_node_owner_cap.is_none() || network_node_owner_cap.borrow().is_authorized(object::id(network_node)),
        ENetworkNodeOwnerCapMismatch,
    );
    assert!(
        network_node_owner_cap.is_none() || network_node.owner_cap_id() == object::id(network_node_owner_cap.borrow()),
        EGateOwnerCapMismatch,
    );

    // Offline the gate if it has a network node
    if (gate.is_online()) {
        gate.offline(network_node, energy_config, &gate_owner_cap);
    };

    // Use the borrowed owner cap to prepare the gate
    prepare_gate(
        gate,
        &gate_owner_cap,
        ctx,
    );

    // Transfer the gate ownership to FTA
    gate_owner_cap.transfer_owner_cap_with_receipt(
        gate_owner_cap_receipt,
        fta.get_owner_character().to_address(),
        ctx,
    );

    // Record the important values
    let record = gate_record::new(
        clock.timestamp_ms(),
        object::id(current_owner),
        ctx.sender(),
        // Gate B values are from this call
        object::id(gate),
        jump_fee,
        clock,
        ctx,
    );
    // Put the record in the table using a unique hash for the pair
    fta.add_gate_record(record);
}

public fun transfer_gate_pair_same_network_node(
    fta: &mut FrontierTransitAuthority,
    current_owner: &Character,
    gate_1: &mut Gate,
    gate_1_owner_cap: OwnerCap<Gate>,
    gate_1_owner_cap_receipt: ReturnOwnerCapReceipt,
    network_node: &mut NetworkNode,
    network_node_owner_cap: Option<OwnerCap<NetworkNode>>,
    network_node_owner_cap_receipt: Option<ReturnOwnerCapReceipt>,
    jump_fee_1: u64,
    gate_2: &mut Gate,
    gate_2_owner_cap: OwnerCap<Gate>,
    gate_2_owner_cap_receipt: ReturnOwnerCapReceipt,
    jump_fee_2: u64,
    energy_config: &EnergyConfig,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    transfer_gate_pair_validation(gate_1, gate_2);

    // This function can only be used if both gates share the same network node
    assert!(
        gate_1.energy_source_id().borrow() == gate_2.energy_source_id().borrow(),
        EDifferentNetworkNodes,
    );

    transfer_gate(
        fta,
        current_owner,
        gate_1,
        gate_1_owner_cap,
        gate_1_owner_cap_receipt,
        network_node,
        &network_node_owner_cap,
        &network_node_owner_cap_receipt,
        jump_fee_1,
        energy_config,
        clock,
        ctx,
    );

    transfer_gate(
        fta,
        current_owner,
        gate_2,
        gate_2_owner_cap,
        gate_2_owner_cap_receipt,
        network_node,
        &network_node_owner_cap,
        &network_node_owner_cap_receipt,
        jump_fee_2,
        energy_config,
        clock,
        ctx,
    );

    // Transfer the network node for gate 1, if it isn't already owned
    if (!fta.gate_network_node_registered(gate_1)) {
        // Transfer the owner cap
        network_node_owner_cap
            .destroy_some()
            .transfer_owner_cap_with_receipt(
                network_node_owner_cap_receipt.destroy_some(),
                fta.get_owner_character().to_address(),
                ctx,
            );
        // Log that we now own the network node
        fta.add_network_node_record(
            network_node_record::new(
                clock.timestamp_ms(),
                object::id(current_owner),
                ctx.sender(),
                object::id(network_node),
            ),
        );
    } else {
        network_node_owner_cap.destroy_none();
        network_node_owner_cap_receipt.destroy_none();
    };
}

public fun transfer_gate_pair(
    fta: &mut FrontierTransitAuthority,
    current_owner: &Character,
    gate_1: &mut Gate,
    gate_1_owner_cap: OwnerCap<Gate>,
    gate_1_owner_cap_receipt: ReturnOwnerCapReceipt,
    network_node_1: &mut NetworkNode,
    network_node_owner_cap_1: Option<OwnerCap<NetworkNode>>,
    network_node_owner_cap_receipt_1: Option<ReturnOwnerCapReceipt>,
    jump_fee_1: u64,
    gate_2: &mut Gate,
    gate_2_owner_cap: OwnerCap<Gate>,
    gate_2_owner_cap_receipt: ReturnOwnerCapReceipt,
    network_node_2: &mut NetworkNode,
    network_node_owner_cap_2: Option<OwnerCap<NetworkNode>>,
    network_node_owner_cap_receipt_2: Option<ReturnOwnerCapReceipt>,
    jump_fee_2: u64,
    energy_config: &EnergyConfig,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    transfer_gate_pair_validation(gate_1, gate_2);

    transfer_gate(
        fta,
        current_owner,
        gate_1,
        gate_1_owner_cap,
        gate_1_owner_cap_receipt,
        network_node_1,
        &network_node_owner_cap_1,
        &network_node_owner_cap_receipt_1,
        jump_fee_1,
        energy_config,
        clock,
        ctx,
    );

    transfer_gate(
        fta,
        current_owner,
        gate_2,
        gate_2_owner_cap,
        gate_2_owner_cap_receipt,
        network_node_2,
        &network_node_owner_cap_2,
        &network_node_owner_cap_receipt_2,
        jump_fee_2,
        energy_config,
        clock,
        ctx,
    );

    // Transfer the network node for gate 1, if it isn't already owned
    if (!fta.gate_network_node_registered(gate_1)) {
        network_node_owner_cap_1
            .destroy_some()
            .transfer_owner_cap_with_receipt(
                network_node_owner_cap_receipt_1.destroy_some(),
                fta.get_owner_character().to_address(),
                ctx,
            );
        // Log that we now own the network node
        fta.add_network_node_record(
            network_node_record::new(
                clock.timestamp_ms(),
                object::id(current_owner),
                ctx.sender(),
                object::id(network_node_1),
            ),
        );
    } else {
        network_node_owner_cap_1.destroy_none();
        network_node_owner_cap_receipt_1.destroy_none();
    };

    // Transfer the network node for gate 2, if it isn't already owned
    if (!fta.gate_network_node_registered(gate_2)) {
        network_node_owner_cap_2
            .destroy_some()
            .transfer_owner_cap_with_receipt(
                network_node_owner_cap_receipt_2.destroy_some(),
                fta.get_owner_character().to_address(),
                ctx,
            );
        // Log that we now own the network node
        fta.add_network_node_record(
            network_node_record::new(
                clock.timestamp_ms(),
                object::id(current_owner),
                ctx.sender(),
                object::id(network_node_2),
            ),
        );
    } else {
        network_node_owner_cap_2.destroy_none();
        network_node_owner_cap_receipt_2.destroy_none();
    };
}

/// Prepares a gate for FTA operation
fun prepare_gate(gate: &mut Gate, gate_owner_cap: &OwnerCap<Gate>, _ctx: &mut TxContext) {
    // TODO: set metadata name using the system/location
    gate.update_metadata_name(gate_owner_cap, b"Frontier Transit Authority".to_string());
    // TODO: configure the authorization extension
}

/// Transfers a gate back to its original owner
public(package) fun return_gate_to_owner(
    fta: &mut FrontierTransitAuthority,
    character: &mut Character,
    gate: &Gate,
    cap_ticket: Receiving<OwnerCap<Gate>>,
    ctx: &mut TxContext,
) {
    // Get the owner cap from FTA
    let (cap, receipt) = access::borrow_gate_owner_cap(fta, character, gate, cap_ticket, ctx);
    // Transfer it to the original owner
    cap.transfer_owner_cap_with_receipt(
        receipt,
        fta.get_gate_record(gate).transferred_from_character_id().to_address(),
        ctx,
    );
    // Remove the gate from the network
    fta.remove_gate_record(gate);
}
