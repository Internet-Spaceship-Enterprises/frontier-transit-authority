---
sidebar_position: 5
---

As with any economy, we expect EVE Frontier to experience inflation over time. Therefore, we must allow flexibility in the FTA pricing and penalty mechanisms to accommodate for this.

FTA pricing, at its core, is set by the [Operators](../Operators/index.md), who specify the fees to use the gates and network nodes they register with the FTA. When [Travelers](../Travelers/index.md) purchase Jump Permits, they are providing social proof that the price they are paying is reasonable. We utilize this knowledge in our Sui Move package so that we don't need to hardcode any fee values, such as penalty fees for destroying FTA infrastructure. Instead, we use multipliers, so FTA-regulated fees (e.g. penalty fees) are dynamically priced based on what travelers have recently been paying for Jump Permits. This approach allows long-term operation of the FTA network without developer intervention.

The implementation of this system can be seen [here](https://github.com/Internet-Spaceship-Enterprises/frontier-transit-authority/blob/cc1bbe74683062228dcc46672475ef7460fb1555/contracts/fta/sources/jumps/jump-history.move#L75-L90), where average fees are calculated, and [here](https://github.com/Internet-Spaceship-Enterprises/frontier-transit-authority/blob/cc1bbe74683062228dcc46672475ef7460fb1555/contracts/fta/sources/killmails/killmail-registry.move#L76-L87), where those average fees are used to set penalty fees for transgressions.