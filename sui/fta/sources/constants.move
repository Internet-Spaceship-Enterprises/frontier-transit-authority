module fta::constants;

/// The additional fee (as a percentage of the gate fee) that goes
/// towards the bounty pool to pay out bounties for killing those
/// unfriendly to FTA.
const BOUNTY_FEE: u64 = 20;

/// The additional fee (as a percentage of the gate fee) that goes
/// to the developers to exchange for SUI tokens on a marketplace to
/// fund gas fees and to encourage additional development.
const DEVELOPER_FEE: u64 = 10;

/// The base validity duration (in milliseconds) for a jump permit
const JUMP_BASE_VALIDITY_DURATION: u64 = 1 * 60 * 1000; // 1 minute
/// The maximum validity duration (in milliseconds) for a jump permit
const JUMP_MAX_VALIDITY_DURATION: u64 = 24 * 60 * 60 * 1000; // 1 day
/// The jump permit fee multiplier at max duration
const JUMP_MAX_VALIDITY_DURATION_MULTIPLIER: u64 = 10; // A permit with max validity is 10x more expensive than a simple just-in-time permit

public(package) fun bounty_fee(): u64 {
    BOUNTY_FEE
}

public(package) fun developer_fee(): u64 {
    DEVELOPER_FEE
}

public(package) fun jump_base_validity_duration(): u64 {
    JUMP_BASE_VALIDITY_DURATION
}

public(package) fun jump_max_validity_duration(): u64 {
    JUMP_MAX_VALIDITY_DURATION
}

public(package) fun jump_max_validity_duration_multiplier(): u64 {
    JUMP_MAX_VALIDITY_DURATION_MULTIPLIER
}
