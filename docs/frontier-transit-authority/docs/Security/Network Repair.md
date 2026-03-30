---
sidebar_position: 1
---

In order for the FTA to remain a decentralized system, we must allow for repair and expansion of the FTA network without developer interaction. Fortunately, the current design of Frontier supports this as it allows:
1. Gates to be powered by Network Nodes that are owned by someone/something else
2. Automatic re-connect of gates to network nodes if a network node is destroyed and rebuilt/replaced

These features allow us to support the following functionality:
1. When a network node is destroyed, the gate will go offline
2. The L-point is now available for anyone to build a new network node there
3. The gate will automatically re-link to the new network node, regardless of who build it
4. The new network node builder can call the FTA function to register their network node, granting them the `ManagementCap` for it that allows them to set fees
5. The gate will now be operational through FTA again

There is, of course, the possibility of malicious behaviour:
1. A player destroys a network node
2. The player then immediately replaces it with their own network node
3. The player does this either to be able to set the jump permit network node fees (gaining revenue for themselves), or to keep the network node offline so the gate remains unpowered/offline, as a method for disabling the gate

Such behaviour is discouraged through FTA mechanisms:
1. Any player destroying infrastructure registered with FTA (including network nodes powering registered gates) will immediately earn both a bounty [TODO: link] and a spot on the blacklist [TODO: link]. These are heavy penalties.
2. Network nodes that have a high "downtime" (unpowered for extended periods of time) will be excluded from the bounty/blacklist penalties. This encourages players to destroy and replace network nodes that are not regularly fueled by their owners (either due to being abandoned, or intentionally to keep the gate offline).
    - We may even pay out a bounty for destroying and replacing network nodes that are often unfueled