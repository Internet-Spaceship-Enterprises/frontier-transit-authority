module fta::donations;

use assets::EVE::EVE;
use fta::fta::FrontierTransitAuthority;
use fta::upgrade_cap::UpgradeCap;
use sui::balance;
use sui::coin::Coin;

/// Donate to the bounty pool of the FTA. This is a one way operation and the funds will be used to pay out jump bounty rewards.
public fun donate_to_bounty_pool(fta: &mut FrontierTransitAuthority, payment: Coin<EVE>) {
    fta.assert_upgrade_cap_exchanged();
    balance::join(fta.bounty_balance_mut(), payment.into_balance());
}

/// Donate to the developer pool of the FTA. This is a one way operation and the funds will be used to fund development work.
public fun donate_to_developer_pool(fta: &mut FrontierTransitAuthority, payment: Coin<EVE>) {
    fta.assert_upgrade_cap_exchanged();
    balance::join(fta.developer_balance(), payment.into_balance());
}

/// Transfers coins from the developer balance to another address
public fun transfer_developer_balance(
    fta: &mut FrontierTransitAuthority,
    _: &UpgradeCap,
    recipient: address,
    value: u64,
) {
    fta.assert_upgrade_cap_exchanged();
    let transfer_balance = fta.developer_balance().split(value);
    transfer_balance.send_funds(recipient);
}
