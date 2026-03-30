module fta::jump;

use assets::EVE::EVE;
use fta::fta::FrontierTransitAuthority;
use fta::jump_estimate::{Self, JumpEstimate};
use sui::balance;
use sui::clock::Clock;
use sui::coin::{Self, Coin};
use world::access::OwnerCap;
use world::character::Character;
use world::gate::Gate;

public struct JumpAuth has drop {}

#[error(code = 1)]
const EWrongSourceGate: vector<u8> =
    b"The source gate on your quote does not match the source gate you have provided";
#[error(code = 2)]
const EWrongDestinationGate: vector<u8> =
    b"The destination gate on your quote does not match the destination gate you have provided";
#[error(code = 3)]
const EWrongPaymentAmount: vector<u8> = b"The wrong payment amount was sent";

public struct JumpQuote {
    estimate: JumpEstimate,
}

// Configures the gate to use our jump extension
public(package) fun init_jump_extension(gate: &mut Gate, gate_owner_cap: &OwnerCap<Gate>) {
    gate.authorize_extension<JumpAuth>(gate_owner_cap);
}

/// Gets an quote for a jump. It must be consumed by using it to purchase the jump permit.
public fun jump_quote(
    fta: &FrontierTransitAuthority,
    source_gate: &Gate,
    destination_gate: &Gate,
    validity_duration: u64,
    clock: &Clock,
): JumpQuote {
    let estimate = jump_estimate::new(fta, source_gate, destination_gate, validity_duration, clock);
    JumpQuote {
        estimate: estimate,
    }
}

/// Issues a jump permit for a jump, given a quote.
/// The quote must be generated with the same source and destination gates, and the correct payment must be provided.
public fun issue_jump_permit(
    fta: &mut FrontierTransitAuthority,
    quote: JumpQuote,
    source_gate: &Gate,
    destination_gate: &Gate,
    character: &Character,
    mut payment: Coin<EVE>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // TODO: check if blacklisted

    // Ensure the provided gates match the invoice gates
    assert!(quote.estimate.source_gate_id() == object::id(source_gate), EWrongSourceGate);
    assert!(
        quote.estimate.destination_gate_id() == object::id(destination_gate),
        EWrongDestinationGate,
    );

    // Ensure the gates are valid (linked, both source and destination are managed by FTA, network nodes present and registered)
    fta.check_gate_validity(source_gate);
    fta.check_gate_validity(destination_gate);

    // Ensure the correct payment was sent
    assert!(
        coin::value(&payment) == quote.estimate.source_gate_fee() + quote.estimate.destination_gate_fee() + quote.estimate.source_network_node_fee() + quote.estimate.destination_network_node_fee() + quote.estimate.bounty_fee() + quote.estimate.developer_fee(),
        EWrongPaymentAmount,
    );

    // Get and transfer the source gate fee
    let source_gate_fee_recipient = fta.get_gate_record(source_gate).fee_recipient();
    let source_gate_fee_coin = payment.split(quote.estimate.source_gate_fee(), ctx);
    source_gate_fee_coin.send_funds(source_gate_fee_recipient);

    // Get and transfer the destination gate fee
    let destination_gate_fee_recipient = fta.get_gate_record(destination_gate).fee_recipient();
    let destination_gate_fee_coin = payment.split(quote.estimate.destination_gate_fee(), ctx);
    destination_gate_fee_coin.send_funds(destination_gate_fee_recipient);

    // Get and transfer the source network node fee
    let source_network_node_fee_recipient = fta
        .get_network_node_record_for_gate(source_gate)
        .fee_recipient();
    let source_network_node_fee_coin = payment.split(quote.estimate.source_network_node_fee(), ctx);
    source_network_node_fee_coin.send_funds(source_network_node_fee_recipient);

    // Get and transfer the destination network node fee
    let destination_network_node_fee_recipient = fta
        .get_network_node_record_for_gate(destination_gate)
        .fee_recipient();
    let destination_network_node_fee_coin = payment.split(
        quote.estimate.destination_network_node_fee(),
        ctx,
    );
    destination_network_node_fee_coin.send_funds(destination_network_node_fee_recipient);

    // Split and transfer the bounty fee
    let bounty_balance = payment.split(quote.estimate.bounty_fee(), ctx).into_balance();
    balance::join(fta.bounty_balance(), bounty_balance);

    // Sanity check that all amounts are correct
    assert!(payment.value() == quote.estimate.developer_fee(), EWrongPaymentAmount);

    // Transfer the developer fee
    balance::join(fta.bounty_balance(), payment.into_balance());

    source_gate.issue_jump_permit(
        destination_gate,
        character,
        JumpAuth {},
        clock.timestamp_ms() + quote.estimate.validity_duration(),
        ctx,
    );
    // Consume the quote
    let JumpQuote {
        estimate: _,
    } = quote;
}

// TODO: refund jump permit
// TODO: restocking fee
