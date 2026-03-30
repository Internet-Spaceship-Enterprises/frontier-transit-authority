module fta::jump;

use assets::EVE::EVE;
use fta::fta::FrontierTransitAuthority;
use fta::jump_estimate::{Self, JumpEstimate};
use fta::jump_quote::{Self, JumpQuote};
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
const EWrongCharacter: vector<u8> =
    b"The character you have provided is different than the character on your quote";
#[error(code = 4)]
const EWrongPaymentAmount: vector<u8> = b"The wrong payment amount was sent";

// Configures the gate to use our jump extension
public(package) fun init_jump_extension(gate: &mut Gate, gate_owner_cap: &OwnerCap<Gate>) {
    gate.authorize_extension<JumpAuth>(gate_owner_cap);
}

public fun jump_estimate(
    fta: &FrontierTransitAuthority,
    character_id: ID,
    source_gate: &Gate,
    destination_gate: &Gate,
    validity_duration: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): JumpEstimate {
    // Ensure both gates are valid and linked
    fta.check_gate_validity(source_gate);
    fta.check_gate_validity(destination_gate);

    jump_estimate::new(
        fta.gate_registry(),
        fta.network_node_registry(),
        character_id,
        source_gate,
        destination_gate,
        validity_duration,
        clock,
        ctx,
    )
}

/// Gets an quote for a jump. It must be consumed by using it to purchase the jump permit.
public fun jump_quote(
    fta: &FrontierTransitAuthority,
    character_id: ID,
    source_gate: &Gate,
    destination_gate: &Gate,
    validity_duration: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): JumpQuote {
    let estimate = jump_estimate(
        fta,
        character_id,
        source_gate,
        destination_gate,
        validity_duration,
        clock,
        ctx,
    );
    jump_quote::new(estimate)
}

/// Issues a jump permit for a jump, given a quote.
/// The quote must be generated with the same source and destination gates, and the correct payment must be provided.
public fun issue_jump_permit(
    fta: &mut FrontierTransitAuthority,
    character: &Character,
    quote: JumpQuote,
    source_gate: &Gate,
    destination_gate: &Gate,
    mut payment: Coin<EVE>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // NOTE: we intentionally do not check if the sender address owns the character,
    // because we want to enable tribes to pay for jumps on behalf of their members

    // Ensure the provided gates match the invoice gates
    assert!(quote.estimate().source_gate_id() == object::id(source_gate), EWrongSourceGate);
    assert!(
        quote.estimate().destination_gate_id() == object::id(destination_gate),
        EWrongDestinationGate,
    );

    // Ensure the provided character matches the quote character
    assert!(quote.estimate().character_id() == character.id(), EWrongCharacter);

    // Ensure the gates are valid (linked, both source and destination are managed by FTA, network nodes present and registered)
    fta.check_gate_validity(source_gate);
    fta.check_gate_validity(destination_gate);

    // Ensure the correct payment was sent
    assert!(
        coin::value(&payment) == quote.estimate().total_base_fee() + quote.estimate().bounty_fee() + quote.estimate().developer_fee(),
        EWrongPaymentAmount,
    );

    // Record the issuance of the permit
    fta
        .jump_history_mut()
        .add(
            quote.estimate(),
            character.id(),
            ctx,
        );

    // Get and transfer the source gate fee
    let source_gate_fee_recipient = fta.gate_registry().get(source_gate).fee_recipient();
    let source_gate_fee_coin = payment.split(quote.estimate().source_gate_fee(), ctx);
    source_gate_fee_coin.send_funds(source_gate_fee_recipient);

    // Get and transfer the destination gate fee
    let destination_gate_fee_recipient = fta.gate_registry().get(destination_gate).fee_recipient();
    let destination_gate_fee_coin = payment.split(quote.estimate().destination_gate_fee(), ctx);
    destination_gate_fee_coin.send_funds(destination_gate_fee_recipient);

    // Get and transfer the source network node fee
    let source_network_node_fee_recipient = fta
        .network_node_registry()
        .get_by_gate(source_gate)
        .fee_recipient();
    let source_network_node_fee_coin = payment.split(
        quote.estimate().source_network_node_fee(),
        ctx,
    );
    source_network_node_fee_coin.send_funds(source_network_node_fee_recipient);

    // Get and transfer the destination network node fee
    let destination_network_node_fee_recipient = fta
        .network_node_registry()
        .get_by_gate(destination_gate)
        .fee_recipient();
    let destination_network_node_fee_coin = payment.split(
        quote.estimate().destination_network_node_fee(),
        ctx,
    );
    destination_network_node_fee_coin.send_funds(destination_network_node_fee_recipient);

    // Split and transfer the bounty fee
    let bounty_balance = payment.split(quote.estimate().bounty_fee(), ctx).into_balance();
    balance::join(fta.bounty_balance(), bounty_balance);

    // Sanity check that all amounts are correct
    assert!(payment.value() == quote.estimate().developer_fee(), EWrongPaymentAmount);

    // Transfer the developer fee
    balance::join(fta.bounty_balance(), payment.into_balance());

    source_gate.issue_jump_permit(
        destination_gate,
        character,
        JumpAuth {},
        clock.timestamp_ms() + quote.estimate().validity_duration(),
        ctx,
    );
    // Consume the quote
    quote.destroy();
}

// TODO: refund jump permit
// TODO: restocking fee
