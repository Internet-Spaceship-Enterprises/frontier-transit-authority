---
sidebar_position: 4
---

In general, the holder of a `ManagementCap` for a Gate or Network Node that has been registered with FTA holds the ability to set the jump permit fees for that gate or network node.

However, there are a few restrictions imposed on fee changes to help maintain the stability and predictability of the network: a minimum notice window, a single pending change at a time, and a maximum fee increase.

### Notice Window
When a fee change is submitted by the player holding the `ManagementCap` for a gate or network node, they must specify the timestamp on which it is to take effect. This "effective date" must be a minimum of 1 week in the future (subject to change). After a change has been submitted, it cannot be modified or revoked, as that fee change information will have been published and other players may be counting on its accuracy.

This limits the frequency at which fees can be modified, improving stability of the network, and ensures that all players/organizations have sufficient time to review a fee change before it takes effect and modify their plans accordingly.

### Single Pending Change
When a fee change has been submitted, no other change can be submitted until it takes effect. This simplifies the FTA design while ensuring all users always know exactly what pricing to expect, but it also means that if you schedule a change now to take effect 1 year from now, you will not be able to make any other fee changes in that 1-year period.

A future iteration may include support for revoking a planned change (the revokation also being subject to a minimum notice period), but that is out-of-scope for this first iteration.

### Maximum Fee Increase
FTA relies on pricing stability while also allowing builders to recover their costs and support their operations. FTA supports both requirements by allowing builders to increase fees, but by limiting the fee increase to 20% of the current value. This value is subject to change, but was selected to enable rapid pricing changes in response to changes in fuel prices, while also preventing price gouging. It allows the competition enough time before prices are doubled or tripled to set up their own FTA-managed gate in the same system if the price of an existing gate is scheduled to increase drastically.
