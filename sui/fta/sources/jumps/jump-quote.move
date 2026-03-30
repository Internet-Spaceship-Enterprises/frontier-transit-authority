module fta::jump_quote;

use fta::jump_estimate::JumpEstimate;

public struct JumpQuote has key {
    id: UID,
    estimate: JumpEstimate,
}

public(package) fun new(estimate: JumpEstimate, ctx: &mut TxContext): JumpQuote {
    JumpQuote {
        id: object::new(ctx),
        estimate,
    }
}

public(package) fun estimate(quote: &JumpQuote): &JumpEstimate {
    &quote.estimate
}

public(package) fun destroy(quote: JumpQuote) {
    let JumpQuote { id, .. } = quote;
    id.delete();
}
