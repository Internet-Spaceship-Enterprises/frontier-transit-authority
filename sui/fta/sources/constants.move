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
const JUMP_BASE_VALIDITY_DURATION: u64 = 2 * 60 * 1000; // 2 minutes
/// The maximum validity duration (in milliseconds) for a jump permit
const JUMP_MAX_VALIDITY_DURATION: u64 = 24 * 60 * 60 * 1000; // 1 day
/// The jump permit fee multiplier at max duration
const JUMP_MAX_VALIDITY_DURATION_MULTIPLIER: u64 = 20; // A permit with max validity is 20x more expensive than a simple just-in-time permit

// The minimum requirement for how long it takes for a new fee to take effect
const FEE_CHANGE_MINIMUM_NOTICE: u64 = 604800000; // 1 week
// The maximum fee percentage increase at a time
const FEE_CHANGE_MAX_PERCENTAGE: u64 = 20; // 20%

/// The period (in milliseconds) to look at when calculating the average jump fee (historical data) for a killmail penalty
const BLACKLIST_PENALTY_AVERAGE_PERIOD: u64 = 30*24*60*60*1000; // Average over the past 30 days
/// The default average jump fee to use for calculating killmail penalties if there isn't enough historical data to calculate an average
const BLACKLIST_DEFAULT_AVG_JUMP_FEE: u64 = 1000;

/// How long, in milliseconds, an upgrade vote is valid for
const UPGRADE_VOTE_VALIDITY_DURATION: u64 = 7 * 24 * 60 * 60 * 1000; // 7 days
/// How long, in milliseconds, to consider for tallying a character's vote weight for an upgrade proposal
/// (i.e. how far back in time to look at their jump history to calculate their vote weight)
const UPGRADE_VOTE_WEIGHT_DURATION: u64 = 6 * 30 * 24 * 60 * 60 * 1000; // 6 months

/// The percentage of online time that network nodes must meet in order for their destruction to qualify for blacklisting/bounty
const NETWORK_NODE_UPTIME_REQUIREMENT_FOR_BLACKLIST: u64 = 40; // 40% minimum uptime requirement
/// The period (in milliseconds) over which to evaluate a network node's online performance for blacklisting decisions
const NETWORK_NODE_UPTIME_REQUIREMENT_PERIOD: u64 = 30 * 24 * 60 * 60 * 1000; // Look at the past 30 days of online performance for blacklisting decisions

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

public(package) fun fee_change_minimum_notice(): u64 {
    FEE_CHANGE_MINIMUM_NOTICE
}

public(package) fun fee_change_max_percentage(): u64 {
    FEE_CHANGE_MAX_PERCENTAGE
}

public(package) fun blacklist_penalty_average_period(): u64 {
    BLACKLIST_PENALTY_AVERAGE_PERIOD
}

public(package) fun blacklist_default_avg_jump_fee(): u64 {
    BLACKLIST_DEFAULT_AVG_JUMP_FEE
}

public(package) fun upgrade_vote_validity_duration(): u64 {
    UPGRADE_VOTE_VALIDITY_DURATION
}

public(package) fun upgrade_vote_weight_duration(): u64 {
    UPGRADE_VOTE_WEIGHT_DURATION
}

public(package) fun network_node_uptime_requirement_for_blacklist(): u64 {
    NETWORK_NODE_UPTIME_REQUIREMENT_FOR_BLACKLIST
}

public(package) fun network_node_uptime_requirement_period(): u64 {
    NETWORK_NODE_UPTIME_REQUIREMENT_PERIOD
}
