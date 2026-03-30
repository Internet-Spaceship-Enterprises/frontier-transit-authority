module fta::donations;

use assets::EVE::EVE;
use fta::fta::FrontierTransitAuthority;
use sui::balance;
use sui::coin::Coin;

/// Donate to the bounty pool of the FTA. This is a one way operation and the funds will be used to pay out jump bounty rewards.
public fun donate_to_bounty_pool(fta: &mut FrontierTransitAuthority, payment: Coin<EVE>) {
    balance::join(fta.bounty_balance_mut(), payment.into_balance());
}

/// Donate to the developer pool of the FTA. This is a one way operation and the funds will be used to fund development work.
public fun donate_to_developer_pool(fta: &mut FrontierTransitAuthority, payment: Coin<EVE>) {
    balance::join(fta.developer_balance(), payment.into_balance());
}
