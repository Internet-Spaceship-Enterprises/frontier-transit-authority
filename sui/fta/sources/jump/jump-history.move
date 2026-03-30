module fta::jump_history;

use fta::jump_estimate::JumpEstimate;
use sui::linked_table::{Self, LinkedTable};

public struct JumpHistoryEntry has store {
    estimate: JumpEstimate,
    character_id: ID,
}

public struct JumpHistory has store {
    entries: LinkedTable<ID, LinkedTable<ID, JumpHistoryEntry>>,
}

public(package) fun new(ctx: &mut TxContext): JumpHistory {
    JumpHistory {
        entries: linked_table::new(ctx),
    }
}

public(package) fun add(
    history: &mut JumpHistory,
    estimate: JumpEstimate,
    character_id: ID,
    ctx: &mut TxContext,
) {
    let entry = JumpHistoryEntry {
        estimate: estimate,
        character_id: character_id,
    };
    if (!history.entries.contains(character_id)) {
        history.entries.push_back(character_id, linked_table::new<ID, JumpHistoryEntry>(ctx));
    };
    history.entries[character_id].push_back(entry.estimate.id(), entry);
}

public(package) fun get_character_fee_total_before_penalty(
    history: &JumpHistory,
    character_id: ID,
    from_timestamp: u64,
    to_timestamp: u64,
): u64 {
    if (!history.entries.contains(character_id)) {
        return 0
    };
    let mut total = 0;
    let character_history = &history.entries[character_id];
    let mut key = character_history.back();
    while (key.is_some()) {
        let k = *key.borrow();
        let entry = &character_history[k];
        key = character_history.prev(k);
        // If the estimate is prepared before the from_timestamp, then we can stop iterating, since we're iterating newest to oldest
        if (entry.estimate.prepared_at() < from_timestamp) {
            break
        };
        if (entry.estimate.prepared_at() > to_timestamp) {
            continue
        };
        // Use the fee before any pentalty factor scaling, as we don't want to give players more credit for having a penalty
        total = total + entry.estimate.total_base_fee() / entry.estimate.penalty_factor();
    };
    total
}
