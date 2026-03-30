module fta::bounty;

use assets::EVE::EVE;
use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::Coin;
use sui::linked_table::{Self, LinkedTable};

public struct BountyEarned has store {
    timestamp: u64,
    value: u64,
}

public struct BountyPaid has store {
    timestamp: u64,
    value: u64,
}

public struct Bounty has store {
    value: u64,
    earned_history: LinkedTable<ID, BountyEarned>,
    paid_history: LinkedTable<ID, BountyPaid>,
}

public(package) fun new(ctx: &mut TxContext): Bounty {
    Bounty {
        value: 0,
        earned_history: linked_table::new(ctx),
        paid_history: linked_table::new(ctx),
    }
}

public(package) fun earn(bounty: &mut Bounty, killmail_id: ID, value: u64, clock: &Clock) {
    bounty.value = bounty.value + value;
    let earned = BountyEarned { timestamp: clock.timestamp_ms(), value };
    bounty.earned_history.push_back(killmail_id, earned);
}

public(package) fun pay(
    bounty: &mut Bounty,
    killmail_id: ID,
    value: u64,
    recipient: address,
    balance: &mut Balance<EVE>,
    clock: &Clock,
) {
    // Payout is the smaller of the bounty value and the balance,
    // since we can't pay out more than we have in the bounty pool
    let payout = std::u64::min(balance.value(), value);
    bounty.value = bounty.value - payout;

    balance.split(payout).send_funds(recipient);

    let paid = BountyPaid { timestamp: clock.timestamp_ms(), value: payout };
    bounty.paid_history.push_back(killmail_id, paid);
}
