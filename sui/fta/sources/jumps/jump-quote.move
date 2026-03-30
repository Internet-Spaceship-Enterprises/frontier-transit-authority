module fta::jump_quote;

use fta::jump_estimate::JumpEstimate;

public struct JumpQuote {
    estimate: JumpEstimate,
}

public(package) fun new(estimate: JumpEstimate): JumpQuote {
    JumpQuote {
        estimate: estimate,
    }
}

public(package) fun destroy(quote: JumpQuote) {
    let JumpQuote {
        estimate: _,
    } = quote;
}

public(package) fun estimate(quote: &JumpQuote): JumpEstimate {
    quote.estimate
}
