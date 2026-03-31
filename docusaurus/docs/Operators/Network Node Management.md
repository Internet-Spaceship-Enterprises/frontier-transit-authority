---
sidebar_position: 3
---

Network nodes are handled differently than gates. In order for a gate to be registered with FTA, the gate's ownership (`OwnerCap<Gate>`) must be transferred to FTA. The ownership of network nodes (`OwnerCap<NetworkNode>`), however, do not get transferred. The Network Node's ownership simply gets registered with FTA to allow the owner to modify the jump permit fees associated with that network node (TODO: see fee structure).

The primary reason for this difference is that if the `OwnerCap<NetworkNode>` was held by the FTA, there would be no way to deposit fuel into the network node. This is because the `network_node::deposit_fuel` function requires a sponsored transaction, meaning it can only be called by the game server, i.e. it needs to be an in-game action. If the `OwnerCap<NetworkNode>` is held by a non-character shared object, then there is no way to interact with the system from in-game and therefore no way to deposit fuel.

Our approach, then, is to allow the original builder to retain ownership of the network node so that they can continue to refuel it. If CCP implements future functionality to allow players to deposit fuel into a network node they do not own, similar to how an extension can be used to allow this kind of trading on a storage unit, then we will revisit this design.

Since the original builders are responsible for continuing to fuel the network node, they must continue to receive fees for doing so to compensate for the cost of fuel and labour to conduct refueling. We address this by separating the jump permit fees into multiple segments (see [fee structure](../Fee%20Structure/index.md)), allowing the gate fee (capital cost) and network node fee (ongoing fuel cost) to be separate. When the owner of a network node that powers a gate is registered with FTA, that owner then gets a `ManagementCap` for the network node. The `ManagementCap` allows them to set fees for the network node in the same way that a gate `ManagementCap` allows setting the fee for a gate, including the ability to modify the recipient address for the fees.

While fee updates have not yet been implemented in the dApp UI, the underlying Sui functionality can be seen [here](https://github.com/Internet-Spaceship-Enterprises/frontier-transit-authority/blob/main/contracts/fta/sources/management/management.move).