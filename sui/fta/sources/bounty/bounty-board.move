module fta::bounty_board;

use assets::EVE::EVE;
use fta::bounty::{Self, Bounty};
use fta::constants;
use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::table::{Self, Table};
use world::character::Character;
use world::killmail::Killmail;

public struct BountyBoard has store {
    character_bounties: Table<ID, Bounty>,
    tribe_bounties: Table<u32, Bounty>,
    // The balance of the bounty account (for paying bounties)
    bounty_balance: Balance<EVE>,
}

public(package) fun new(ctx: &mut TxContext): BountyBoard {
    BountyBoard {
        character_bounties: table::new(ctx),
        tribe_bounties: table::new(ctx),
        bounty_balance: balance::zero(),
    }
}

public(package) fun bounty_balance(bounty_board: &BountyBoard): &Balance<EVE> {
    &bounty_board.bounty_balance
}

public(package) fun bounty_balance_mut(bounty_board: &mut BountyBoard): &mut Balance<EVE> {
    &mut bounty_board.bounty_balance
}

/// Add a bounty
public(package) fun add(
    bounty_board: &mut BountyBoard,
    killmail: &Killmail,
    killer: &Character,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // Set a bounty on the character
    {
        // If there's no bounty being tracked for this character, add one
        if (!bounty_board.character_bounties.contains(killer.id())) {
            bounty_board.character_bounties.add(killer.id(), bounty::new(ctx));
        };
        let bounty = bounty_board.character_bounties.borrow_mut(killer.id());

        // TODO: once more data is available in killmails, dynamically select a bounty value based on the value of the destroyed asset
        let value = constants::character_bounty_default_value();

        // Log the bounty
        bounty.earn(killmail.id(), value, clock);
    };

    // Set a bounty on the tribe, if they have one
    // TODO: are there NPC tribes that should be excluded?
    if (killer.tribe() != 0) {
        // If there's no bounty being tracked for this tribe, add one
        if (!bounty_board.tribe_bounties.contains(killer.tribe())) {
            bounty_board.tribe_bounties.add(killer.tribe(), bounty::new(ctx));
        };
        let bounty = bounty_board.tribe_bounties.borrow_mut(killer.tribe());

        // TODO: once more data is available in killmails, dynamically select a bounty value based on the value of the destroyed asset
        // For now, use a fixed value defined in a constant.
        let value = constants::tribe_bounty_default_value();

        // Log the bounty
        bounty.earn(killmail.id(), value, clock);
    }
}

/// Process a killmail to pay out any bounty for it
public(package) fun pay(
    bounty_board: &mut BountyBoard,
    killmail: &Killmail,
    killer: &Character,
    victim: &Character,
    clock: &Clock,
) {
    // Check if there's a bounty on the victim character
    if (bounty_board.character_bounties.contains(victim.id())) {
        let bounty = bounty_board.character_bounties.borrow_mut(victim.id());
        let value = bounty.value();

        // TODO: once killmails have more data, calculate this payout based on the value of the destroyed asset.
        // For now, just pay 10% of the remaining bounty for this character
        let payout = value / 10; // Pay out 10% of the bounty value
        bounty.pay(
            killmail.id(),
            payout,
            killer.character_address(),
            &mut bounty_board.bounty_balance,
            clock,
        );
    };

    // Now check if there's a bounty on the tribe
    if (bounty_board.tribe_bounties.contains(victim.tribe())) {
        // There's a bounty on the tribe, so pay that out
        let bounty = bounty_board.tribe_bounties.borrow_mut(victim.tribe());
        let value = bounty.value();
        // TODO: once killmails have more data, calculate this payout based on the value of the destroyed asset.
        // For now, just pay 2% of the remaining bounty for this tribe
        let payout = value / 50; // Pay out 2% of the bounty value
        bounty.pay(
            killmail.id(),
            payout,
            killer.character_address(),
            &mut bounty_board.bounty_balance,
            clock,
        );
    };
}
