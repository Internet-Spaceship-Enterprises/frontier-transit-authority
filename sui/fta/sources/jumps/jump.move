module fta::jump;

use assets::EVE::EVE;
use fta::blacklist::Blacklist;
use fta::constants;
use fta::gate_control;
use fta::gate_registry::GateRegistry;
use fta::jump_auth::{Self, JumpAuth};
use fta::jump_history::JumpHistory;
use fta::jump_quote::JumpQuote;
use fta::network_node_registry::NetworkNodeRegistry;
use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::coin::Coin;
use world::access::OwnerCap;
use world::character::Character;
use world::energy::EnergyConfig;
use world::gate::Gate;
use world::network_node::NetworkNode;

#[error(code = 1)]
const EWrongSourceGate: vector<u8> =
    b"The source gate on your quote does not match the source gate you have provided";
#[error(code = 2)]
const EWrongDestinationGate: vector<u8> =
    b"The destination gate on your quote does not match the destination gate you have provided";
#[error(code = 3)]
const EWrongCharacter: vector<u8> =
    b"The character you have provided is different than the character on your quote";
#[error(code = 4)]
const EWrongPaymentAmount: vector<u8> = b"The wrong payment amount was sent";
#[error(code = 5)]
const EWrongNetworkNode: vector<u8> = b"The wrong network node was provided";
#[error(code = 6)]
const ENetworkNodeOffline: vector<u8> = b"The network node is offline";
#[error(code = 7)]
const EQuoteExpired: vector<u8> = b"The jump quote has expired";

// Configures the gate to use our jump extension
public(package) fun init_jump_extension(gate: &mut Gate, gate_owner_cap: &OwnerCap<Gate>) {
    gate.authorize_extension<JumpAuth>(gate_owner_cap);
}

/// Issues a jump permit for a jump, given a quote.
/// The quote must be generated with the same source and destination gates, and the correct payment must be provided.
public(package) fun issue_jump_permit(
    gate_registry: &GateRegistry,
    network_node_registry: &NetworkNodeRegistry,
    jump_history: &mut JumpHistory,
    blacklist: &mut Blacklist,
    bounty_balance: &mut Balance<EVE>,
    developer_balance: &mut Balance<EVE>,
    character: &Character,
    quote: JumpQuote,
    source_gate: &mut Gate,
    source_gate_owner_cap: &OwnerCap<Gate>,
    source_network_node: &mut NetworkNode,
    destination_gate: &mut Gate,
    destination_gate_owner_cap: &OwnerCap<Gate>,
    destination_network_node: &mut NetworkNode,
    mut payment: Coin<EVE>,
    energy_config: &EnergyConfig,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // NOTE: we intentionally do not check if the sender address owns the character
    // because we want to enable tribes to pay for jumps on behalf of their members

    // Ensure the provided gates match the invoice gates
    assert!(quote.source_gate_id() == object::id(source_gate), EWrongSourceGate);
    assert!(quote.destination_gate_id() == object::id(destination_gate), EWrongDestinationGate);

    // Ensure the provided character matches the quote character
    assert!(quote.character_id() == character.id(), EWrongCharacter);

    let timestamp = clock.timestamp_ms();

    // Ensure the quote is recent enough to still be valid
    assert!(timestamp - quote.prepared_at() <= constants::jump_quote_validity_ms(), EQuoteExpired);

    // Ensure the correct network nodes were provided
    assert!(
        object::id(source_network_node) == source_gate.energy_source_id().borrow(),
        EWrongNetworkNode,
    );
    assert!(
        object::id(destination_network_node) == destination_gate.energy_source_id().borrow(),
        EWrongNetworkNode,
    );

    // Ensure the network nodes are online
    assert!(source_network_node.is_network_node_online(), ENetworkNodeOffline);
    assert!(destination_network_node.is_network_node_online(), ENetworkNodeOffline);

    // Power up the gates!
    gate_control::change_gate_online(
        gate_registry,
        network_node_registry,
        source_gate,
        source_gate_owner_cap,
        source_network_node,
        true,
        energy_config,
    );
    gate_control::change_gate_online(
        gate_registry,
        network_node_registry,
        destination_gate,
        destination_gate_owner_cap,
        destination_network_node,
        true,
        energy_config,
    );

    let source_gate_fee_recipient = gate_registry.get(source_gate).fee_recipient();
    let source_gate_fee_coin = payment.split(quote.source_gate_fee_scaled(), ctx);
    source_gate_fee_coin.send_funds(source_gate_fee_recipient);

    // Get and transfer the destination gate fee
    let destination_gate_fee_recipient = gate_registry.get(destination_gate).fee_recipient();
    let destination_gate_fee_coin = payment.split(
        quote.destination_gate_fee_scaled(),
        ctx,
    );
    destination_gate_fee_coin.send_funds(destination_gate_fee_recipient);

    // Get and transfer the source network node fee
    let source_network_node_fee_recipient = network_node_registry
        .get_by_gate(source_gate)
        .fee_recipient();
    let source_network_node_fee_coin = payment.split(
        quote.source_network_node_fee_scaled(),
        ctx,
    );
    source_network_node_fee_coin.send_funds(source_network_node_fee_recipient);

    // Get and transfer the destination network node fee
    let destination_network_node_fee_recipient = network_node_registry
        .get_by_gate(destination_gate)
        .fee_recipient();
    let destination_network_node_fee_coin = payment.split(
        quote.destination_network_node_fee_scaled(),
        ctx,
    );
    destination_network_node_fee_coin.send_funds(destination_network_node_fee_recipient);

    // Split and transfer the developer fee
    let developer_fee = payment.split(quote.developer_fee(), ctx).into_balance();
    balance::join(developer_balance, developer_fee);

    // Sanity check that the remaining amount is correct
    assert!(payment.value() == quote.total_bounty_fee(), EWrongPaymentAmount);
    // Transfer the bounty fee
    balance::join(bounty_balance, payment.into_balance());

    let permit_id = source_gate.issue_jump_permit_with_id(
        destination_gate,
        character,
        jump_auth::new(),
        timestamp + quote.validity_duration(),
        ctx,
    );

    // Record the issuance of the permit
    jump_history.add(blacklist, quote, object::id(character), permit_id, ctx);
}
