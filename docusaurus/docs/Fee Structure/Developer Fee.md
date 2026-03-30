---
sidebar_position: 4
---

The Developer Pool Fee is calculated as a percentage of the total jump permit fee. The exact percentage is specified in the FTA package as a constant and can only be updated with consensus from the user community (cannot be unilaterally modified by the developers).

The Developer Pool Fee goes to the Developer Pool, which the FTA developers can withdraw from. These funds are used for two purposes:
1. For the developers to exchange for SUI tokens, in order to pay gas fees for Sui calls that are necessary to keep the FTA running.
2. As a profit for the developers to encourage continued active development of the FTA.

### Ongoing Gas Costs
Maintaining the FTA unfortunately requires ongoing SUI gas costs, which represent real-world financial costs for the developers. Even once the gas fees have been paid to deploy the FTA contracts or future versions of them, "write" functions (requiring gas) must be called on a regular basis to feed Frontier world data into the Sui chain. 

For example, consider the bounty system. In order to calculate and pay out bounties, a list of Killmails must be fed into the FTA contract on a regular basis so they can be processed to determine if bountied characters were killed and who should receive the payout, and to actually conduct the payout. Since these operations cost gas, players will not perform them on FTA's behalf and it falls to the developers to set up automated scheduling of these functions (and paying the associated gas costs) to keep everything running.