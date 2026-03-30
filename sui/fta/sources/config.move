module fta::config;

use fta::fta::FrontierTransitAuthority;
use sui::clock::Clock;
use world::gate::Gate;

// Updates the fee for a gate
public fun update_fee(
    fta: &mut FrontierTransitAuthority,
    gate: &Gate,
    jump_fee: u64,
    takes_effect_on: u64,
    clock: &Clock,
    ctx: &TxContext,
) {
    let gate_record = fta.get_gate_record_mut(gate);
    gate_record.update_fee(jump_fee, takes_effect_on, clock, ctx);
}
