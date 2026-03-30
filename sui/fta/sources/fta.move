/*
/// Module: frontier_transit_authority
module fta::fta;
*/
module fta::fta;

use assets::EVE::EVE;
use fta::blacklist::{Self, Blacklist};
use fta::gate_registry::{Self, GateRegistry};
use fta::jump_estimate::JumpEstimate;
use fta::jump_history::{Self, JumpHistory};
use fta::killmail_registry::{Self, KillmailRegistry};
use fta::network_node_registry::{Self, NetworkNodeRegistry};
use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::package::Publisher;
use world::gate::Gate;
use world::killmail::Killmail;
use world::object_registry::ObjectRegistry;

#[error(code = 1)]
const EGateNotInNetwork: vector<u8> = b"This gate is not part of the Frontier Transit Authority";
#[error(code = 2)]
const ELinkedGateNotInNetwork: vector<u8> =
    b"The gate linked to this gate is not part of the Frontier Transit Authority";
#[error(code = 3)]
const ENoLinkedGate: vector<u8> = b"You cannot perform an operation on a gate that is not linked";
#[error(code = 5)]
const EGateNetworkNodeNotRegistered: vector<u8> =
    b"The network node for this gate is not registered with the Frontier Transit Authority";

/// The OTW for the module.
public struct FTA has drop {}

/// Developer capability
public struct DeveloperCap has key { id: UID }

public struct FrontierTransitAuthority has key {
    // TODO: swap fields to dynamic fields for upgradability
    id: UID,
    deployer_addr: address,
    gate_registry: GateRegistry,
    jump_history: JumpHistory,
    network_node_registry: NetworkNodeRegistry,
    killmail_registry: KillmailRegistry,
    blacklist: Blacklist,
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

    let fta = FrontierTransitAuthority {
        id: object::new(ctx),
        deployer_addr: ctx.sender(),
        gate_registry: gate_registry::new(ctx),
        network_node_registry: network_node_registry::new(ctx),
        jump_history: jump_history::new(ctx),
        killmail_registry: killmail_registry::new(ctx),
        blacklist: blacklist::new(ctx),
        bounty_balance: balance::zero(),
        developer_balance: balance::zero(),
    };

    // Create the Transit Authority object and make it shared
    // TODO: should this use a OTW?
    transfer::share_object(fta);
}

public(package) fun uid(fta: &FrontierTransitAuthority): &UID {
    &fta.id
}

public(package) fun uid_mut(fta: &mut FrontierTransitAuthority): &mut UID {
    &mut fta.id
}

public(package) fun blacklist(fta: &FrontierTransitAuthority): &Blacklist {
    &fta.blacklist
}

public(package) fun blacklist_mut(fta: &mut FrontierTransitAuthority): &mut Blacklist {
    &mut fta.blacklist
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

//=================================
// Blacklist operations
//=================================

/// Processes a batch of killmails, updating the gate and network node registries and the blacklist as necessary.
public fun process_killmails(
    fta: &mut FrontierTransitAuthority,
    killmails: &vector<Killmail>,
    object_registry: &ObjectRegistry,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let len = killmails.length();
    let mut i = 0;
    while (i < len) {
        let killmail = vector::borrow(killmails, i); // borrow element by index
        fta
            .killmail_registry
            .process_killmail(
                killmail,
                &mut fta.gate_registry,
                &mut fta.network_node_registry,
                &mut fta.jump_history,
                &mut fta.blacklist,
                object_registry,
                clock,
                ctx,
            );
        i = i + 1;
    }
}

//=================================
// Gate operations
//=================================

/// Asserts that a gate is owned by the FTA. Use primarily for testing.
public fun assert_gate_managed(fta: &mut FrontierTransitAuthority, gate: &Gate) {
    fta.gate_registry.registered(gate);
}

//=================================
// Jump operations
//=================================

public(package) fun jump_history_add(
    fta: &mut FrontierTransitAuthority,
    estimate: JumpEstimate,
    character_id: ID,
    ctx: &mut TxContext,
) {
    fta.jump_history.add(&mut fta.blacklist, estimate, character_id, ctx);
}
