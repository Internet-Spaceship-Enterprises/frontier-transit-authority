module fta::developer;

use fta::fta::{FrontierTransitAuthority, DeveloperCap};

/// Transfers coins from the developer balance to another address
public fun transfer_developer_balance(
    fta: &mut FrontierTransitAuthority,
    _: &DeveloperCap,
    recipient: address,
    value: u64,
) {
    let transfer_balance = fta.developer_balance().split(value);
    transfer_balance.send_funds(recipient);
}

// TODO: upgrade logic
