---
sidebar_position: 2
---

Currently, linking gates can only be done in-game because it requires a sponsored transaction (`gate::link_gates()`). This means that once gates are transferred to FTA, a non-character shared object, there's no way to modify the links without transferring the gate ownership to a character first (which would allow the character to "steal" the gate).

This leads to a problem where any FTA gate that has its linked gate destroyed will be "orphaned" and there's no way to link it to a new gate. To address this issue, when one of a pair of linked gates gets destroyed, the other gate in the pair will be returned to the character that holds the `ManagementCap` for that gate.

That character can then link it to a new gate, then transfer the linked gates back to FTA.

This behaviour will be modified once [dynamic gate linking](../Future%20Work/Dynamic%20Network.md) is supported, as FTA will be able to re-link the gate with any other gate on-demand.