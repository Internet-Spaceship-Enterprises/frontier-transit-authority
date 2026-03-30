module fta::registration;

use fta::access;
use fta::fta::{FrontierTransitAuthority, DeveloperCap};
use fta::gate_record;
use fta::jump::JumpAuth;
use fta::network_node_record;
use sui::clock::Clock;
use sui::transfer::Receiving;
use world::access::{OwnerCap, ReturnOwnerCapReceipt};
use world::character::Character;
use world::energy::EnergyConfig;
use world::gate::Gate;
use world::location::LocationRegistry;
use world::network_node::NetworkNode;

#[error(code = 1)]
const EGateOwnerCapMismatch: vector<u8> = b"OwnerCap<Gate> does not belong to this Gate";
#[error(code = 2)]
const ENetworkNodeOwnerCapMismatch: vector<u8> =
    b"OwnerCap<NetworkNode> does not belong to this NetworkNode";
#[error(code = 3)]
const EGatesNotLinked: vector<u8> = b"The two gates being transferred must be linked";
#[error(code = 4)]
const EWrongNetworkNode: vector<u8> =
    b"The NetworkNode provided is not the correct one for this Gate";
// Removed because network nodes are currently not transferred
// #[error(code = 5)]
// const ENoNetworkNodeOwnerCapProvided: vector<u8> =
//     b"If the gate is connected to a network node that is not already owned by FTA, then the network node's OwnerCap and Receipt must be provided";
#[error(code = 6)]
const EGateHasNoNetworkNode: vector<u8> =
    b"A gate cannot be transferred to FTA if it is not connected to a network node";
#[error(code = 7)]
const EDifferentNetworkNodes: vector<u8> =
    b"If using the `transfer_gate_pair_same_network_node` function, both gates must be linked to the same network node";
#[error(code = 8)]
const ELocationNotRevealed: vector<u8> =
    b"You cannot transfer a gate to FTA unless the location has been revealed (using the in-game UI)";
#[error(code = 9)]
const EWrongCharacter: vector<u8> = b"The provided character is not yours";
#[error(code = 10)]
const ENetworkNodeAlreadyRegistered: vector<u8> =
    b"The provided network node is already registered";
#[error(code = 11)]
const ENetworkNodeNotRegistered: vector<u8> =
    b"A gate cannot be transferred to FTA if its network node is not already registered with FTA";

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
    // network_node_owner_cap: &Option<OwnerCap<NetworkNode>>,
    // network_node_owner_cap_receipt: &Option<ReturnOwnerCapReceipt>,
    jump_fee: u64,
    fee_recipient: address,
    energy_config: &EnergyConfig,
    location_registry: &LocationRegistry,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // Ensure the location has been revealed, since we can't do it afterwards
    assert!(location_registry.get_location(object::id(gate)).is_some(), ELocationNotRevealed);

    // Ensure the provided character is correct
    assert!(current_owner.character_address() == ctx.sender(), EWrongCharacter);

    // Ensure the correct network node was provided
    assert!(gate.energy_source_id().borrow() == object::id(network_node), EWrongNetworkNode);

    // Ensure the gate owner cap provided is the right one for the gate
    assert!(gate_owner_cap.is_authorized(object::id(gate)), EGateOwnerCapMismatch);
    assert!(gate.owner_cap_id() == object::id(&gate_owner_cap), EGateOwnerCapMismatch);

    // Ensure the gate is linked, since we can't link it after it's been transferred
    assert!(!gate.linked_gate_id().is_none(), EGatesNotLinked);

    // Ensure that the associated network node is already registered
    assert!(fta.network_node_registry().registered(network_node), ENetworkNodeNotRegistered);

    // Ensure that either the owner cap was provided or we already own it
    // assert!(
    //     fta.gate_network_node_registered(gate) || (network_node_owner_cap.is_some() && network_node_owner_cap_receipt.is_some()),
    //     ENoNetworkNodeOwnerCapProvided,
    // );
    // // Ensure the network node owner cap provided is the right one for the network node
    // assert!(
    //     network_node_owner_cap.is_none() || network_node_owner_cap.borrow().is_authorized(object::id(network_node)),
    //     ENetworkNodeOwnerCapMismatch,
    // );
    // assert!(
    //     network_node_owner_cap.is_none() || network_node.owner_cap_id() == object::id(network_node_owner_cap.borrow()),
    //     EGateOwnerCapMismatch,
    // );

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
        object::id(fta).to_address(),
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
        fee_recipient,
        clock,
        ctx,
    );
    // Put the record in the table using a unique hash for the pair
    fta.gate_registry_mut().add(record);
}

public fun transfer_gate_pair_same_network_node(
    fta: &mut FrontierTransitAuthority,
    current_owner: &Character,
    gate_1: &mut Gate,
    gate_1_owner_cap: OwnerCap<Gate>,
    gate_1_owner_cap_receipt: ReturnOwnerCapReceipt,
    network_node: &mut NetworkNode,
    // network_node_owner_cap: Option<OwnerCap<NetworkNode>>,
    // network_node_owner_cap_receipt: Option<ReturnOwnerCapReceipt>,
    jump_fee_1: u64,
    fee_recipient_1: address,
    gate_2: &mut Gate,
    gate_2_owner_cap: OwnerCap<Gate>,
    gate_2_owner_cap_receipt: ReturnOwnerCapReceipt,
    jump_fee_2: u64,
    fee_recipient_2: address,
    energy_config: &EnergyConfig,
    location_registry: &LocationRegistry,
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
        // &network_node_owner_cap,
        // &network_node_owner_cap_receipt,
        jump_fee_1,
        fee_recipient_1,
        energy_config,
        location_registry,
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
        // &network_node_owner_cap,
        // &network_node_owner_cap_receipt,
        jump_fee_2,
        fee_recipient_2,
        energy_config,
        location_registry,
        clock,
        ctx,
    );

    // Transfer the network node for gate 1, if it isn't already owned
    // if (!fta.gate_network_node_registered(gate_1)) {
    //     // Transfer the owner cap
    //     network_node_owner_cap
    //         .destroy_some()
    //         .transfer_owner_cap_with_receipt(
    //             network_node_owner_cap_receipt.destroy_some(),
    //             fta.get_owner_character().to_address(),
    //             ctx,
    //         );
    //     // Log that we now own the network node
    //     fta.add_network_node_record(
    //         network_node_record::new(
    //             clock.timestamp_ms(),
    //             object::id(current_owner),
    //             ctx.sender(),
    //             object::id(network_node),
    //         ),
    //     );
    // } else {
    //     network_node_owner_cap.destroy_none();
    //     network_node_owner_cap_receipt.destroy_none();
    // };
}

public fun transfer_gate_pair(
    fta: &mut FrontierTransitAuthority,
    current_owner: &Character,
    gate_1: &mut Gate,
    gate_1_owner_cap: OwnerCap<Gate>,
    gate_1_owner_cap_receipt: ReturnOwnerCapReceipt,
    network_node_1: &mut NetworkNode,
    // network_node_owner_cap_1: Option<OwnerCap<NetworkNode>>,
    // network_node_owner_cap_receipt_1: Option<ReturnOwnerCapReceipt>,
    jump_fee_1: u64,
    fee_recipient_1: address,
    gate_2: &mut Gate,
    gate_2_owner_cap: OwnerCap<Gate>,
    gate_2_owner_cap_receipt: ReturnOwnerCapReceipt,
    network_node_2: &mut NetworkNode,
    // network_node_owner_cap_2: Option<OwnerCap<NetworkNode>>,
    // network_node_owner_cap_receipt_2: Option<ReturnOwnerCapReceipt>,
    jump_fee_2: u64,
    fee_recipient_2: address,
    energy_config: &EnergyConfig,
    location_registry: &LocationRegistry,
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
        // &network_node_owner_cap_1,
        // &network_node_owner_cap_receipt_1,
        jump_fee_1,
        fee_recipient_1,
        energy_config,
        location_registry,
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
        // &network_node_owner_cap_2,
        // &network_node_owner_cap_receipt_2,
        jump_fee_2,
        fee_recipient_2,
        energy_config,
        location_registry,
        clock,
        ctx,
    );

    // // Transfer the network node for gate 1, if it isn't already owned
    // if (!fta.gate_network_node_registered(gate_1)) {
    //     network_node_owner_cap_1
    //         .destroy_some()
    //         .transfer_owner_cap_with_receipt(
    //             network_node_owner_cap_receipt_1.destroy_some(),
    //             fta.get_owner_character().to_address(),
    //             ctx,
    //         );
    //     // Log that we now own the network node
    //     fta.add_network_node_record(
    //         network_node_record::new(
    //             clock.timestamp_ms(),
    //             object::id(current_owner),
    //             ctx.sender(),
    //             object::id(network_node_1),
    //         ),
    //     );
    // } else {
    //     network_node_owner_cap_1.destroy_none();
    //     network_node_owner_cap_receipt_1.destroy_none();
    // };

    // // Transfer the network node for gate 2, if it isn't already owned
    // if (!fta.gate_network_node_registered(gate_2)) {
    //     network_node_owner_cap_2
    //         .destroy_some()
    //         .transfer_owner_cap_with_receipt(
    //             network_node_owner_cap_receipt_2.destroy_some(),
    //             fta.get_owner_character().to_address(),
    //             ctx,
    //         );
    //     // Log that we now own the network node
    //     fta.add_network_node_record(
    //         network_node_record::new(
    //             clock.timestamp_ms(),
    //             object::id(current_owner),
    //             ctx.sender(),
    //             object::id(network_node_2),
    //         ),
    //     );
    // } else {
    //     network_node_owner_cap_2.destroy_none();
    //     network_node_owner_cap_receipt_2.destroy_none();
    // };
}

/// Registers a network node to be used in FTA operations.
/// For now, it does not actually transfer ownership, it just tracks the fees associated with using it.
public fun register_network_node(
    fta: &mut FrontierTransitAuthority,
    current_owner: &Character,
    network_node: &mut NetworkNode,
    network_node_owner_cap: &OwnerCap<NetworkNode>,
    jump_fee: u64,
    fee_recipient: address,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // If it's already registered, bail out
    if (fta.network_node_registry().registered(network_node)) {
        return
    };
    assert!(!fta.network_node_registry().registered(network_node), ENetworkNodeAlreadyRegistered);
    // Ensure the network node owner cap provided is the right one for the network node
    assert!(
        network_node_owner_cap.is_authorized(object::id(network_node)),
        ENetworkNodeOwnerCapMismatch,
    );
    assert!(
        network_node.owner_cap_id() == object::id(network_node_owner_cap),
        ENetworkNodeOwnerCapMismatch,
    );
    fta
        .network_node_registry_mut()
        .add(
            network_node_record::new(
                clock.timestamp_ms(),
                object::id(current_owner),
                ctx.sender(),
                object::id(network_node),
                jump_fee,
                fee_recipient,
                clock,
                ctx,
            ),
        );
}

/// Prepares a gate for FTA operation
fun prepare_gate(gate: &mut Gate, gate_owner_cap: &OwnerCap<Gate>, _ctx: &mut TxContext) {
    // TODO: set metadata name using the system/location
    gate.update_metadata_name(gate_owner_cap, b"Frontier Transit Authority".to_string());
    // Authorize the JumpAuth extension for FTA to be able to issue jump permits
    gate.authorize_extension<JumpAuth>(gate_owner_cap);
}

/// Transfers a gate back to its original owner
/// TODO: change this to a private function without the DevCap
public fun return_gate_to_owner(
    fta: &mut FrontierTransitAuthority,
    _: &DeveloperCap,
    gate: &mut Gate,
    owner_cap_ticket: Receiving<OwnerCap<Gate>>,
    ctx: &mut TxContext,
) {
    let record = fta.gate_registry().get(gate);
    let owner_addr = record.management_cap_owner_address();
    let owner_cap = access::borrow_gate_owner_cap_no_receipt(fta, gate, owner_cap_ticket, ctx);

    // Remove the gate from the network
    fta.gate_registry_mut().deregister(gate, &owner_cap);

    // Send the OwnerCap to the entity that holds the ManagementCap
    world::access::transfer_owner_cap(owner_cap, owner_addr);
}
