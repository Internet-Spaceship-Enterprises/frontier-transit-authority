module fta::blacklist_penalties;

use sui::vec_map::{Self, VecMap};

public struct Penalty has copy, drop, store {
    /// The additional multiplier (1+N) to apply to all jump fees while a penalty for destroying an item is active
    destroyed_penalty_factor: u64,
    /// The multiplier of the average jump fee that the player has to pay off before this penalty for destroying an item is removed.
    /// For example, if the average jump fee is 1000 and the penalty_fee_multiplier is 2000,
    /// then the player has to pay 2,000,000 (2000 * 1000) to remove this penalty.
    destroyed_penalty_fee_multiplier: u64,
    /// The additional multiplier (1+N) to apply to all jump fees while a penalty for damaging an item is active
    damaged_penalty_factor: u64,
    /// The multiplier of the average jump fee that the player has to pay off before this penalty for damaging an item is removed.
    /// For example, if the average jump fee is 1000 and the penalty_fee_multiplier is 2000,
    /// then the player has to pay 2,000,000 (2000 * 1000) to remove this penalty.
    damaged_penalty_fee_multiplier: u64,
}

public struct BlacklistPenalties has store {
    penalties_by_type: VecMap<u64, Penalty>,
}

public(package) fun new(): BlacklistPenalties {
    let mut penalties = vec_map::empty();

    // Mini gate
    penalties.insert(
        88086,
        Penalty {
            destroyed_penalty_factor: 5000, // 50x jump fee multiplier for destroying an item
            destroyed_penalty_fee_multiplier: 1000, // 1000x average jump fee to remove penalty for destroying an item
            damaged_penalty_factor: 500, // 5x jump fee multiplier for damaging an item
            damaged_penalty_fee_multiplier: 100, // 100x average jump fee to remove penalty for damaging an item
        },
    );

    // Heavy gate
    penalties.insert(
        84955,
        Penalty {
            destroyed_penalty_factor: 10000, // 100x jump fee multiplier for destroying
            destroyed_penalty_fee_multiplier: 20000, // 2000x average jump fee to remove penalty for destroying an item
            damaged_penalty_factor: 1000, // 10x jump fee multiplier for damaging an item
            damaged_penalty_fee_multiplier: 2000, // 200x average jump fee to remove penalty for damaging an item
        },
    );

    // Network Node
    penalties.insert(
        88092,
        Penalty {
            destroyed_penalty_factor: 1000, // 10x jump fee multiplier for destroying
            destroyed_penalty_fee_multiplier: 2000, // 200x average jump fee to remove penalty for destroying an item
            damaged_penalty_factor: 100, // 1x jump fee multiplier for damaging an item
            damaged_penalty_fee_multiplier: 200, // 20x average jump fee to remove penalty for damaging an item
        },
    );

    BlacklistPenalties {
        penalties_by_type: penalties,
    }
}

// TODO: switch this to a match instead of storing in a table
public(package) fun get(penalties: &BlacklistPenalties, item_type: u64): Penalty {
    if (!penalties.penalties_by_type.contains(&item_type)) {
        return default()
    };
    *penalties.penalties_by_type.get(&item_type)
}

public(package) fun default(): Penalty {
    Penalty {
        destroyed_penalty_factor: 5000, // Default to 50x jump fee multiplier for destroying an item
        destroyed_penalty_fee_multiplier: 1000, // Default to 1000x average jump fee to remove penalty for destroying an item
        damaged_penalty_factor: 500, // Default to 5x jump fee multiplier for damaging an item
        damaged_penalty_fee_multiplier: 100, // Default to 100x average jump fee to remove penalty for damaging an item
    }
}

public(package) fun destroyed_penalty_factor(penalty: &Penalty): u64 {
    penalty.destroyed_penalty_factor
}

public(package) fun destroyed_penalty_fee_multiplier(penalty: &Penalty): u64 {
    penalty.destroyed_penalty_fee_multiplier
}

public(package) fun damaged_penalty_factor(penalty: &Penalty): u64 {
    penalty.damaged_penalty_factor
}

public(package) fun damaged_penalty_fee_multiplier(penalty: &Penalty): u64 {
    penalty.damaged_penalty_fee_multiplier
}
