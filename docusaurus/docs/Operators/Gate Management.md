---
sidebar_position: 2
---

Although players transfer gate ownership to the FTA when they register a gate with the network, this does not mean that they shouldn't have ongoing rights to manage some aspects of the gate operation. Specifically, they should be able to modify the jump permit pricing to accommodate for inflation or other dynamic pricing factors.

FTA supports this by issuing a `ManagementCap` for any gate that is transferred to FTA. The `ManagementCap` allows the original gate owner to access certain privileged operations for that gate, including:
1. Updating the [jump fees for that gate](../Fee%20Structure/Gate%20Fee.md)
2. Changing which address jump fees for that gate are sent to

The `ManagementCap` can be freely transferred to any other address, so players can delegate management authority or build complex custom logic to implement dynamic pricing.

While fee updates have not yet been implemented in the dApp UI, the underlying Sui functionality can be seen [here](https://github.com/Internet-Spaceship-Enterprises/frontier-transit-authority/blob/main/contracts/fta/sources/management/management.move).