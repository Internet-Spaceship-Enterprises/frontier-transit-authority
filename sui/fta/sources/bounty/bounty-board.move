module fta::bounty_board;

use assets::EVE::EVE;
use fta::bounty::Bounty;
use sui::balance::{Self, Balance};
use sui::linked_table::{Self, LinkedTable};

public struct BountyBoard has store {
    character_bounties: LinkedTable<ID, Bounty>,
    tribe_bounties: LinkedTable<ID, Bounty>,
    // The balance of the bounty account (for paying bounties)
    bounty_balance: Balance<EVE>,
}

public(package) fun new(ctx: &mut TxContext): BountyBoard {
    BountyBoard {
        character_bounties: linked_table::new(ctx),
        tribe_bounties: linked_table::new(ctx),
        bounty_balance: balance::zero(),
    }
}

public(package) fun bounty_balance(bounty_board: &BountyBoard): &Balance<EVE> {
    &bounty_board.bounty_balance
}

public(package) fun bounty_balance_mut(bounty_board: &mut BountyBoard): &mut Balance<EVE> {
    &mut bounty_board.bounty_balance
}
ERROR
// TODO: functions for managing character and tribe bounties
// TODO: call these functions from killmail processing
