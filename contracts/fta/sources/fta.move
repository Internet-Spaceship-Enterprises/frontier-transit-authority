/*
/// Module: frontier_transit_authority
module fta::fta;
*/
module fta::fta;

use assets::EVE::EVE;
use fta::blacklist::{Self, Blacklist};
use fta::bounty_board::{Self, BountyBoard};
use fta::gate_registry::{Self, GateRegistry};
use fta::jump;
use fta::jump_estimate::{Self, JumpEstimate};
use fta::jump_history::{Self, JumpHistory};
use fta::jump_quote::{Self, JumpQuote};
use fta::killmail_registry::{Self, KillmailRegistry};
use fta::network_node_registry::{Self, NetworkNodeRegistry};
use fta::upgrade_cap::{Self, UpgradeCap};
use fta::upgrades::{Self, UpgradeManager};
use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::coin::Coin;
use sui::package::{Self, Publisher};
use sui::transfer::Receiving;
use world::access::{Self, OwnerCap, ReturnOwnerCapReceipt};
use world::character::Character;
use world::energy::EnergyConfig;
use world::gate::Gate;
use world::killmail::Killmail;
use world::location::LocationRegistry;
use world::network_node::NetworkNode;
use world::object_registry::ObjectRegistry;

#[error(code = 1)]
const EGateNotInNetwork: vector<u8> = b"This gate is not part of the Frontier Transit Authority";
#[error(code = 2)]
const ELinkedGateNotInNetwork: vector<u8> =
    b"The gate linked to this gate is not part of the Frontier Transit Authority";
#[error(code = 3)]
const ENoLinkedGate: vector<u8> = b"You cannot perform an operation on a gate that is not linked";
#[error(code = 4)]
const EGateNetworkNodeNotRegistered: vector<u8> =
    b"The network node for this gate is not registered with the Frontier Transit Authority";
#[error(code = 5)]
const EUpgradeCapNotExchanged: vector<u8> =
    b"The upgrade cap has not been exchanged for a custom one, making this package insecure to use";
#[error(code = 6)]
const EWrongOwnerCap: vector<u8> = b"The provided OwnerCap is not the right one for this assembly";
#[error(code = 7)]
const EWrongSender: vector<u8> =
    b"The returned OwnerCap receipt does not match the sender of the transaction";

/// The OTW for the module.
public struct FTA has drop {}

public struct FrontierTransitAuthority has key {
    // TODO: swap fields to dynamic fields for upgradability
    id: UID,
    deployer_addr: address,
    upgrade_cap_exchanged: bool,
    upgrade_manager: UpgradeManager,
    gate_registry: GateRegistry,
    jump_history: JumpHistory,
    network_node_registry: NetworkNodeRegistry,
    killmail_registry: KillmailRegistry,
    blacklist: Blacklist,
    bounty_board: BountyBoard,
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
        upgrade_cap_exchanged: false,
        upgrade_manager: upgrades::new_upgrade_manager(),
        gate_registry: gate_registry::new(ctx),
        network_node_registry: network_node_registry::new(ctx),
        jump_history: jump_history::new(ctx),
        killmail_registry: killmail_registry::new(ctx),
        blacklist: blacklist::new(ctx),
        bounty_board: bounty_board::new(ctx),
        developer_balance: balance::zero(),
    };

    // Share the FTA with the world!
    transfer::share_object(fta);
}

/// Exchange the default UpgradeCap for a custom one with much stricter permissions.
/// Transfers the new upgrade cap to the sender of the transaction and returns the ID of the new cap.
public fun exchange_upgrade_cap(
    fta: &mut FrontierTransitAuthority,
    original_upgrade_cap: package::UpgradeCap,
    ctx: &mut TxContext,
): ID {
    // Mark that the upgrade cap has been exchanged, so now upgrades are restricted
    // to group consensus for security.
    fta.upgrade_cap_exchanged = true;
    let new_cap = upgrade_cap::new_upgrade_cap(original_upgrade_cap, ctx);
    let new_cap_id = object::id(&new_cap);
    new_cap.transfer(ctx.sender());
    new_cap_id
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

public(package) fun bounty_board(fta: &FrontierTransitAuthority): &BountyBoard {
    &fta.bounty_board
}

public(package) fun bounty_board_mut(fta: &mut FrontierTransitAuthority): &mut BountyBoard {
    &mut fta.bounty_board
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

public(package) fun bounty_balance_mut(fta: &mut FrontierTransitAuthority): &mut Balance<EVE> {
    fta.bounty_board.bounty_balance_mut()
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

public(package) fun assert_upgrade_cap_exchanged(fta: &FrontierTransitAuthority) {}

//=================================
// Access operations
//=================================

public struct OwnerCapReceipt<phantom T> {
    owner_id: address,
    owner_cap_id: ID,
}

fun borrow_owner_cap<T: key>(
    fta: &mut FrontierTransitAuthority,
    cap_ticket: Receiving<OwnerCap<T>>,
    ctx: &TxContext,
): (OwnerCap<T>, OwnerCapReceipt<T>) {
    // Get the owner cap and receipt
    let owner_cap = access::receive_owner_cap(fta.uid_mut(), cap_ticket);
    let receipt = OwnerCapReceipt<T> {
        owner_id: ctx.sender(),
        owner_cap_id: object::id(&owner_cap),
    };
    (owner_cap, receipt)
}

/// Returns an OwnerCap<Gate> to the FTA
public(package) fun return_owner_cap<T: key>(
    fta: &FrontierTransitAuthority,
    owner_cap: OwnerCap<T>,
    receipt: OwnerCapReceipt<T>,
    ctx: &TxContext,
) {
    // Ensure the right thing is being returned
    assert!(object::id(&owner_cap) == receipt.owner_cap_id, EWrongOwnerCap);
    assert!(ctx.sender() == receipt.owner_id, EWrongSender);
    access::transfer_owner_cap(owner_cap, object::id(fta).to_address());
    // Consume the receipt
    let OwnerCapReceipt<T> {
        owner_id: _,
        owner_cap_id: _,
    } = receipt;
}

// Transfers an OwnerCap to a recipient outside of the FTA
public(package) fun transfer_owner_cap<T: key>(
    fta: &mut FrontierTransitAuthority,
    cap_ticket: Receiving<OwnerCap<T>>,
    recipient: address,
    ctx: &TxContext,
) {
    let (
        cap,
        OwnerCapReceipt<T> {
            owner_id: _,
            owner_cap_id: _,
        },
    ) = borrow_owner_cap(fta, cap_ticket, ctx);
    access::transfer_owner_cap(cap, recipient);
}

/// Borrows an OwnerCap<Gate> from the FTA for privileged operations
public(package) fun borrow_gate_owner_cap(
    fta: &mut FrontierTransitAuthority,
    gate: &Gate,
    cap_ticket: Receiving<OwnerCap<Gate>>,
    ctx: &TxContext,
): (OwnerCap<Gate>, OwnerCapReceipt<Gate>) {
    // Ensure FTA controls the gate
    assert!(fta.gate_registry().registered(gate), EGateNotInNetwork);

    // Get the owner cap and receipt
    let (owner_cap, receipt) = borrow_owner_cap(fta, cap_ticket, ctx);

    // Ensure the correct OwnerCap was passed in
    assert!(gate.owner_cap_id() == object::id(&owner_cap), EWrongOwnerCap);
    (owner_cap, receipt)
}

/// Borrows an OwnerCap<Gate> from the FTA for privileged operations, without a return receipt (DANGEROUS)
public(package) fun borrow_gate_owner_cap_no_receipt(
    fta: &mut FrontierTransitAuthority,
    gate: &Gate,
    cap_ticket: Receiving<OwnerCap<Gate>>,
    ctx: &TxContext,
): OwnerCap<Gate> {
    // Ensure FTA controls the gate
    assert!(fta.gate_registry().registered(gate), EGateNotInNetwork);

    // Get the owner cap and receipt
    let (
        owner_cap,
        OwnerCapReceipt<Gate> {
            owner_id: _,
            owner_cap_id: _,
        },
    ) = borrow_owner_cap(fta, cap_ticket, ctx);

    // Ensure the correct OwnerCap was passed in
    assert!(gate.owner_cap_id() == object::id(&owner_cap), EWrongOwnerCap);
    owner_cap
}

//=================================
// Registration operations
//=================================

/// Registers a network node with the FTA
public fun register_network_node(
    fta: &mut FrontierTransitAuthority,
    current_owner: &Character,
    network_node: &NetworkNode,
    network_node_owner_cap: &OwnerCap<NetworkNode>,
    jump_fee: u64,
    fee_recipient: address,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    fta.assert_upgrade_cap_exchanged();
    fta
        .network_node_registry
        .register(
            current_owner,
            network_node,
            network_node_owner_cap,
            jump_fee,
            fee_recipient,
            clock,
            ctx,
        );
}

/// Registers a pair of gates with the FTA when both gates are linked to the same network node (for localnet testing)
public fun register_gate_pair_same_network_node(
    fta: &mut FrontierTransitAuthority,
    current_owner: &Character,
    gate_1: &mut Gate,
    gate_1_owner_cap: OwnerCap<Gate>,
    gate_1_owner_cap_receipt: ReturnOwnerCapReceipt,
    network_node: &mut NetworkNode,
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
    fta.assert_upgrade_cap_exchanged();
    let fta_addr = object::id(fta).to_address();
    fta
        .gate_registry
        .transfer_gate_pair_same_network_node(
            fta_addr,
            &fta.network_node_registry,
            current_owner,
            gate_1,
            gate_1_owner_cap,
            gate_1_owner_cap_receipt,
            network_node,
            jump_fee_1,
            fee_recipient_1,
            gate_2,
            gate_2_owner_cap,
            gate_2_owner_cap_receipt,
            jump_fee_2,
            fee_recipient_2,
            energy_config,
            location_registry,
            clock,
            ctx,
        );
}

/// Registers a pair of gates (which have different network nodes) with the FTA
public fun register_gate_pair(
    fta: &mut FrontierTransitAuthority,
    current_owner: &Character,
    gate_1: &mut Gate,
    gate_1_owner_cap: OwnerCap<Gate>,
    gate_1_owner_cap_receipt: ReturnOwnerCapReceipt,
    network_node_1: &mut NetworkNode,
    jump_fee_1: u64,
    fee_recipient_1: address,
    gate_2: &mut Gate,
    gate_2_owner_cap: OwnerCap<Gate>,
    gate_2_owner_cap_receipt: ReturnOwnerCapReceipt,
    network_node_2: &mut NetworkNode,
    jump_fee_2: u64,
    fee_recipient_2: address,
    energy_config: &EnergyConfig,
    location_registry: &LocationRegistry,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    fta.assert_upgrade_cap_exchanged();
    let fta_addr = object::id(fta).to_address();
    fta
        .gate_registry
        .transfer_gate_pair(
            fta_addr,
            &fta.network_node_registry,
            current_owner,
            gate_1,
            gate_1_owner_cap,
            gate_1_owner_cap_receipt,
            network_node_1,
            jump_fee_1,
            fee_recipient_1,
            gate_2,
            gate_2_owner_cap,
            gate_2_owner_cap_receipt,
            network_node_2,
            jump_fee_2,
            fee_recipient_2,
            energy_config,
            location_registry,
            clock,
            ctx,
        );
}

/// Deregisters a gate from the FTA and transfers ownership to whoever holds the ManagementCap for it
public fun deregister_gate(
    fta: &mut FrontierTransitAuthority,
    _: &UpgradeCap,
    gate: &mut Gate,
    owner_cap: Receiving<OwnerCap<Gate>>,
    ctx: &mut TxContext,
) {
    fta.assert_upgrade_cap_exchanged();
    let owner_cap = borrow_gate_owner_cap_no_receipt(fta, gate, owner_cap, ctx);
    fta.gate_registry.deregister(gate, owner_cap);
}

//=================================
// Blacklist operations
//=================================

/// Processes a batch of killmails, updating the gate and network node registries and the blacklist as necessary.
public fun process_killmail(
    fta: &mut FrontierTransitAuthority,
    killmail: &Killmail,
    killer: &Character,
    victim: &Option<Character>,
    object_registry: &ObjectRegistry,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    fta.assert_upgrade_cap_exchanged();
    fta
        .killmail_registry
        .process_killmail(
            killmail,
            killer,
            victim,
            &mut fta.gate_registry,
            &mut fta.network_node_registry,
            &mut fta.jump_history,
            &mut fta.blacklist,
            &mut fta.bounty_board,
            object_registry,
            clock,
            ctx,
        );
}

//=================================
// Gate operations
//=================================

/// Asserts that a gate is owned by the FTA. Use primarily for testing.
public fun assert_gate_managed(fta: &mut FrontierTransitAuthority, gate: &Gate) {
    fta.assert_upgrade_cap_exchanged();
    fta.gate_registry.registered(gate);
}

/// Updates the metadata for a registered gate
public fun update_gate_metadata(
    fta: &mut FrontierTransitAuthority,
    gate: &mut Gate,
    gate_owner_cap: Receiving<OwnerCap<Gate>>,
    location_registry: &LocationRegistry,
    ctx: &mut TxContext,
) {
    fta.assert_upgrade_cap_exchanged();
    let (cap, receipt) = borrow_gate_owner_cap(fta, gate, gate_owner_cap, ctx);
    fta.gate_registry.update_gate_metadata(gate, &cap, location_registry);
    return_owner_cap(fta, cap, receipt, ctx)
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
) {
    fta.assert_upgrade_cap_exchanged();
    let len = network_nodes.length();
    let mut i = 0;
    while (i < len) {
        let network_node = vector::borrow(network_nodes, i); // borrow element by index
        let record = fta.network_node_registry.get_by_id_mut(network_node.id());
        record.online_check(network_node, clock);
        i = i + 1;
    }
}

//=================================
// Jump operations
//=================================

/// Prepares an estimate for a jump between two gates, which can be used to inform the user of the cost of the jump before they commit to purchasing the permit
public fun jump_estimate(
    fta: &mut FrontierTransitAuthority,
    character: &Character,
    source_gate: &Gate,
    destination_gate: &Gate,
    validity_duration: u64,
    clock: &Clock,
): JumpEstimate {
    fta.assert_upgrade_cap_exchanged();
    // Ensure both gates are valid and linked
    fta.check_gate_validity(source_gate);
    fta.check_gate_validity(destination_gate);
    jump_estimate::new(
        &fta.gate_registry,
        &fta.network_node_registry,
        &fta.blacklist,
        object::id(character),
        source_gate,
        destination_gate,
        validity_duration,
        clock,
    )
}

/// Prepares a quote for a jump between two gates, which is an object that the user can then use to purchase a jump permit.
public fun jump_quote(
    fta: &mut FrontierTransitAuthority,
    character: &Character,
    source_gate: &Gate,
    destination_gate: &Gate,
    validity_duration: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): JumpQuote {
    fta.assert_upgrade_cap_exchanged();
    // Ensure both gates are valid and linked
    fta.check_gate_validity(source_gate);
    fta.check_gate_validity(destination_gate);
    jump_quote::new(
        jump_estimate::new(
            &fta.gate_registry,
            &fta.network_node_registry,
            &fta.blacklist,
            object::id(character),
            source_gate,
            destination_gate,
            validity_duration,
            clock,
        ),
        ctx,
    )
}

/// Issues a jump permit for a jump between two gates, given a quote that was prepared beforehand
public fun jump_permit(
    fta: &mut FrontierTransitAuthority,
    quote: JumpQuote,
    character: &Character,
    source_gate: &mut Gate,
    source_gate_owner_cap: Receiving<OwnerCap<Gate>>,
    source_network_node: &mut NetworkNode,
    destination_gate: &mut Gate,
    destination_gate_owner_cap: Receiving<OwnerCap<Gate>>,
    destination_network_node: &mut NetworkNode,
    payment: Coin<EVE>,
    energy_config: &EnergyConfig,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    fta.assert_upgrade_cap_exchanged();
    // Ensure the gates are valid (linked, both source and destination are managed by FTA, network nodes present and registered)
    fta.check_gate_validity(source_gate);
    fta.check_gate_validity(destination_gate);
    // Borrow the owner caps
    let (source_cap, source_receipt) = borrow_gate_owner_cap(
        fta,
        source_gate,
        source_gate_owner_cap,
        ctx,
    );
    let (dest_cap, dest_receipt) = borrow_gate_owner_cap(
        fta,
        destination_gate,
        destination_gate_owner_cap,
        ctx,
    );
    // Issue the permit
    jump::issue_jump_permit(
        &fta.gate_registry,
        &fta.network_node_registry,
        &mut fta.jump_history,
        &mut fta.blacklist,
        fta.bounty_board.bounty_balance_mut(),
        &mut fta.developer_balance,
        character,
        quote,
        source_gate,
        &source_cap,
        source_network_node,
        destination_gate,
        &dest_cap,
        destination_network_node,
        payment,
        energy_config,
        clock,
        ctx,
    );
    // Return the owner caps
    return_owner_cap(fta, source_cap, source_receipt, ctx);
    return_owner_cap(fta, dest_cap, dest_receipt, ctx);
}

//=================================
// Upgrade operations
//=================================

/// Propose a new package upgrade.
/// Only the developers (holders of the modified UpgradeCap) can call this function.
public fun propose(
    fta: &mut FrontierTransitAuthority,
    _: &UpgradeCap,
    digest: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    fta.assert_upgrade_cap_exchanged();
    fta.upgrade_manager.propose(digest, clock, ctx);
}

/// Clears the current upgrade proposal
public fun clear_proposal(fta: &mut FrontierTransitAuthority, _: &UpgradeCap) {
    fta.assert_upgrade_cap_exchanged();
    fta.upgrade_manager.clear_proposal();
}

/// Clears a failed proposal after voting has concluded and the result has been determined to be a failure
public fun clear_failed_proposal(
    fta: &mut FrontierTransitAuthority,
    _: &UpgradeCap,
    clock: &Clock,
) {
    fta.assert_upgrade_cap_exchanged();
    fta.upgrade_manager.clear_failed_proposal(clock);
}

/// Checks the voting on a proposal to authorize the upgrade if it has passed
public fun authorize_upgrade(
    fta: &mut FrontierTransitAuthority,
    cap: &mut UpgradeCap,
    digest: vector<u8>,
    clock: &Clock,
): package::UpgradeTicket {
    fta.assert_upgrade_cap_exchanged();
    fta.upgrade_manager.authorize_upgrade(cap, digest, clock)
}

/// Vote on a proposal
public fun vote(
    fta: &mut FrontierTransitAuthority,
    character: &Character,
    in_favour: bool,
    jump_history: &mut JumpHistory,
    clock: &Clock,
    ctx: &TxContext,
) {
    fta.assert_upgrade_cap_exchanged();
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
