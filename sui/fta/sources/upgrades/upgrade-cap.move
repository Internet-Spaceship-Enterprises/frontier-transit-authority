module fta::upgrade_cap;

use sui::package;

public struct UpgradeCap has key, store {
    id: UID,
    cap: package::UpgradeCap,
}

/// Exchange the default UpgradeCap for a custom one with much stricter permissions.
public(package) fun new_upgrade_cap(
    original_upgrade_cap: package::UpgradeCap,
    ctx: &mut TxContext,
): UpgradeCap {
    UpgradeCap {
        id: object::new(ctx),
        cap: original_upgrade_cap,
    }
}

public(package) fun transfer(cap: UpgradeCap, recipient: address) {
    transfer::transfer(cap, recipient);
}

public(package) fun authorize_upgrade(
    cap: &mut UpgradeCap,
    digest: vector<u8>,
): package::UpgradeTicket {
    // Authorize the upgrade and return the UpgradeTicket
    cap.cap.authorize_upgrade(package::compatible_policy(), digest)
}

/// Commits the upgrade after it has been authorized and the new package has been published.
public fun commit_upgrade(cap: &mut UpgradeCap, receipt: package::UpgradeReceipt) {
    cap.cap.commit_upgrade(receipt)
}
