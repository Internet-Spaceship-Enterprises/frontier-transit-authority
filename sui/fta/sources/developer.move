module fta::developer;

use fta::fta::FrontierTransitAuthority;
use fta::upgrades::UpgradeCap;

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
