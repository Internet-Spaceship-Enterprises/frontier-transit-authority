---
sidebar_position: 2
---

The FTA does not belong to any one player or organization. It utilizes Sui's Shared Object model, where all players have equal access to the FTA's functions and capabilities. This is an intentional design choice to make it impossible for the developers to conduct malicious activity, or any activity at all other than what is approved by the community through the [upgrade](./Upgrades.md) process.

We understand that the only way a community system like this can function is if players can verify the integrity of the system and trust that the gates they transfer to it cannot be stolen, and that they are guaranteed to continue to receive fees for their contributions.

We encourage pull requests, criticism, and other feedback from the community to identify security risks and areas for improvement.

:::danger[Security Issue]
Currently, an `OwnerCap<Gate>` can be transferred to a Sui shared object (the FTA), but cannot then ever be retrieved, used, or re-transferred. This is a limitation of CCP's world contracts, but they have promised a fix to this issue.

In the meantime, for demonstration/hackathon purposes, the `OwnerCap<Gate>` is held by a character instead of by the FTA shared object so it can be retrieved and used. This is not a secure design, as there is nothing preventing that character (controlled by the developers) from transferring the gate ownership anywhere else, or taking malicous actions on the gate.
:::
