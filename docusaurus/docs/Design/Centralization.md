---
sidebar_position: 1
---

Operating a gate network requires central control of the core infrastructure. For example, if a gate is offline due to its network node running out of fuel, the FTA needs to be able to bring the gate back online. These kinds of actions require the `OwnerCap<Gate>`, thereby requiring the FTA shared object to own the `OwnerCap` for the gate.

Central authority/ownership also allows more complex operations of the gate network as CCP adds new features. For example:
- CCP has confirmed that they may remove the `admin_acl` requirement from the `gate::link_gates()` function. This would allow [dynamic linking/unlinking](../Future%20Work/Dynamic%20Network.md) of gates (reconfiguration of the gate network) to allow on-demand changes, significantly expanding the reach of the FTA.
- CCP has confirmed that they may allow non-owners of network nodes to deposit fuel into a network node. If FTA holds the `OwnerCap<NetworkNode>` for the network node, it would allow automated purchasing and depositing of fuel from any player who wishes to resupply the network node.

Central authority also prevents malicious behaviour of modifying gate availability by the original owner. An alternative design for FTA would have been to apply a custom extension to a gate that continued to be owned by a player, but this would have permitted the player to:
- Remove the gate from FTA at any time, such as when the gate may be used by an attacking force
- Offline the gate or remove the extension, thereby removing the gate from the FTA network
- Add additional logic to restrict which players may use the gate

FTA is intended to be an open, community-driven, reliable, and safe transit network for all players to use. Allowing gate owners to conduct the above actions at no notice would violate those principles by allowing malicious behaviour, preferential or discriminatory treatment, or intentional disruption of the network.