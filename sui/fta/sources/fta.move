/*
/// Module: frontier_transit_authority
module fta::fta;
*/
module fta::fta;

use assets::EVE::EVE;
use fta::constants;
use fta::gate_registry::{Self, GateRegistry};
use fta::jump_history::{Self, JumpHistory};
use fta::network_node_registry::{Self, NetworkNodeRegistry};
use sui::balance::{Self, Balance};
use sui::dynamic_field as df;
use sui::package::Publisher;
use world::character::Character;
use world::gate::Gate;

#[error(code = 1)]
const EGateNotInNetwork: vector<u8> = b"This gate is not part of the Frontier Transit Authority";
#[error(code = 2)]
const ELinkedGateNotInNetwork: vector<u8> =
    b"The gate linked to this gate is not part of the Frontier Transit Authority";
#[error(code = 3)]
const ENoLinkedGate: vector<u8> = b"You cannot perform an operation on a gate that is not linked";
#[error(code = 4)]
const EOwnerCharacterNotSet: vector<u8> = b"The owner character dynamic field has not been set";
#[error(code = 5)]
const EGateNetworkNodeNotRegistered: vector<u8> =
    b"The network node for this gate is not registered with the Frontier Transit Authority";

/// The OTW for the module.
public struct FTA has drop {}

/// Developer capability
public struct DeveloperCap has key { id: UID }

public struct FrontierTransitAuthority has key {
    id: UID,
    deployer_addr: address,
    gate_registry: GateRegistry,
    jump_history: JumpHistory,
    network_node_registry: NetworkNodeRegistry,
    // The balance of the bounty account (for paying bounties)
    bounty_balance: Balance<EVE>,
    // The balance of the developer account (to fund development efforts and Sui transaction fees)
    developer_balance: Balance<EVE>,
}

// Called only once, upon module publication. It must be
// private to prevent external invocation.
fun init(otw: FTA, ctx: &mut TxContext) {
    // Claim the Publisher object.
    let publisher: Publisher = sui::package::claim(otw, ctx);

    // Transfer it to the publisher address
    transfer::public_transfer(publisher, ctx.sender());

    // Transfers the DeveloperCap to the sender (publisher).
    transfer::transfer(
        DeveloperCap {
            id: object::new(ctx),
        },
        ctx.sender(),
    );

    // Create the Transit Authority object and make it shared
    // TODO: should this use a OTW?
    transfer::share_object(FrontierTransitAuthority {
        id: object::new(ctx),
        deployer_addr: ctx.sender(),
        gate_registry: gate_registry::new(ctx),
        network_node_registry: network_node_registry::new(ctx),
        jump_history: jump_history::new(ctx),
        bounty_balance: balance::zero(),
        developer_balance: balance::zero(),
    });
}

// Configures the character that should own the gates
// TODO: once there's a way to receive the OwnerCap<Gate> without it needing to be owned by a character,
// switch this to the shared object so only approved operations in the contract can use it.
public fun set_owner_character(
    fta: &mut FrontierTransitAuthority,
    _: &DeveloperCap,
    character: &mut Character,
    ctx: &TxContext,
) {
    assert!(ctx.sender() == fta.deployer_addr);
    assert!(character.character_address() == ctx.sender());
    df::add(&mut fta.id, constants::owner_character_field_name(), object::id(character));
}

// Gets the ID of the character that holds gate ownership
public fun get_owner_character(fta: &FrontierTransitAuthority): ID {
    assert!(df::exists_(&fta.id, constants::owner_character_field_name()), EOwnerCharacterNotSet);
    *df::borrow(&fta.id, constants::owner_character_field_name())
}

/// Asserts that a gate is valid for jump or update operations
public(package) fun check_gate_validity(fta: &FrontierTransitAuthority, gate: &Gate) {
    let linked_gate_id_opt = gate.linked_gate_id();
    // Ensure the gate is linked to another gate
    assert!(linked_gate_id_opt.is_some(), ENoLinkedGate);
    let linked_gate_id = linked_gate_id_opt.borrow();
    // Ensure this gate is in the network
    assert!(fta.gate_registry.registered(gate), EGateNotInNetwork);
    // Ensure the linked gate is in the network
    assert!(fta.gate_registry.registered_by_id(*linked_gate_id), ELinkedGateNotInNetwork);
    // Ensure the network node for this gate is registered
    assert!(
        fta.network_node_registry.registered_by_id(*gate.energy_source_id().borrow()),
        EGateNetworkNodeNotRegistered,
    );
}

public(package) fun gate_registry(fta: &FrontierTransitAuthority): &GateRegistry {
    &fta.gate_registry
}

public(package) fun gate_registry_mut(fta: &mut FrontierTransitAuthority): &mut GateRegistry {
    &mut fta.gate_registry
}

public(package) fun network_node_registry(fta: &FrontierTransitAuthority): &NetworkNodeRegistry {
    &fta.network_node_registry
}

public(package) fun jump_history(fta: &FrontierTransitAuthority): &JumpHistory {
    &fta.jump_history
}

public(package) fun jump_history_mut(fta: &mut FrontierTransitAuthority): &mut JumpHistory {
    &mut fta.jump_history
}

public(package) fun network_node_registry_mut(
    fta: &mut FrontierTransitAuthority,
): &mut NetworkNodeRegistry {
    &mut fta.network_node_registry
}

public(package) fun bounty_balance(fta: &mut FrontierTransitAuthority): &mut Balance<EVE> {
    &mut fta.bounty_balance
}

public(package) fun developer_balance(fta: &mut FrontierTransitAuthority): &mut Balance<EVE> {
    &mut fta.developer_balance
}
