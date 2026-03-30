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
use fta::upgrades::{Self, UpgradeCap, UpgradeManager};
use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::package::{Self, Publisher};
use world::character::Character;
use world::gate::Gate;
use world::killmail::Killmail;
use world::network_node::NetworkNode;
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

public struct FrontierTransitAuthority has key {
    // TODO: swap fields to dynamic fields for upgradability
    id: UID,
    deployer_addr: address,
    upgrade_manager: UpgradeManager,
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

    let fta = FrontierTransitAuthority {
        id: object::new(ctx),
        deployer_addr: ctx.sender(),
        upgrade_manager: upgrades::new_upgrade_manager(),
        gate_registry: gate_registry::new(ctx),
        network_node_registry: network_node_registry::new(ctx),
        jump_history: jump_history::new(ctx),
        killmail_registry: killmail_registry::new(ctx),
        blacklist: blacklist::new(ctx),
        bounty_balance: balance::zero(),
        developer_balance: balance::zero(),
    };

    // Send the FTA to the publisher address so they can use it
    // in the publish transaction to create the custom upgrade capability.
    transfer::transfer(fta, ctx.sender());
}

/// Exchange the default UpgradeCap for a custom one with much stricter permissions.
#[allow(lint(share_owned))]
public fun exchange_upgrade_cap(
    fta: FrontierTransitAuthority,
    original_upgrade_cap: package::UpgradeCap,
    ctx: &mut TxContext,
): UpgradeCap {
    // Only once the upgrade cap is exchanged should the FTA be shared with the world,
    // to prevent any funny business by the developers.
    transfer::share_object(fta);
    // Exchange the upgrade cap and return it
    upgrades::new_upgrade_cap(original_upgrade_cap, ctx)
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
// Network node operations
//=================================

/// Loops through provided network nodes and performs a status check on each.
/// This is primarily for tracking the online status of network nodes over time,
/// which can be used to inform bounties on network nodes that are frequently offline.
public fun network_node_update(
    fta: &mut FrontierTransitAuthority,
    network_nodes: &vector<NetworkNode>,
    clock: &Clock,
) { let len = network_nodes.length(); let mut i = 0; while (i < len) {
        let network_node = vector::borrow(network_nodes, i); // borrow element by index
        let record = fta.network_node_registry.get_by_id_mut(network_node.id());
        record.online_check(network_node, clock);
        i = i + 1;
    } }

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

//=================================
// Upgrade operations
//=================================

/// Propose a new package upgrade.
/// Only the developers (holders of the modified UpgradeCap) can call this function.
public(package) fun propose(
    fta: &mut FrontierTransitAuthority,
    _: &UpgradeCap,
    digest: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    fta.upgrade_manager.propose(digest, clock, ctx);
}

/// Clears the current upgrade proposal
public(package) fun clear_proposal(fta: &mut FrontierTransitAuthority, _: &UpgradeCap) {
    fta.upgrade_manager.clear_proposal();
}

/// Vote on a proposal
public(package) fun vote(
    fta: &mut FrontierTransitAuthority,
    character: &Character,
    in_favour: bool,
    jump_history: &mut JumpHistory,
    clock: &Clock,
    ctx: &TxContext,
) {
    fta
        .upgrade_manager
        .vote(
            character,
            in_favour,
            jump_history,
            clock,
            ctx,
        );
}

/// Clears a failed proposal after voting has concluded and the result has been determined to be a failure
public(package) fun clear_failed_proposal(
    fta: &mut FrontierTransitAuthority,
    _: &UpgradeCap,
    clock: &Clock,
) {
    fta.upgrade_manager.clear_failed_proposal(clock);
}

/// Checks the voting on a proposal to authorize the upgrade if it has passed
public(package) fun authorize_upgrade(
    fta: &mut FrontierTransitAuthority,
    cap: &mut UpgradeCap,
    digest: vector<u8>,
    clock: &Clock,
): package::UpgradeTicket {
    fta.upgrade_manager.authorize_upgrade(cap, digest, clock)
}
