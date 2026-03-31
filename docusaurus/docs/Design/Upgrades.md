---
sidebar_position: 3
---

If the developers are able to freely upgrade/modify the FTA contracts, players will never be able to trust that the FTA will continue to play by its own rules. Therefore, we have implemented a strictly controlled upgrade system to ensure that the FTA contracts can only be modified with community consent.

When characters use the FTA network to move around the universe, their fee payments are recorded on-chain. Characters earn "voting rights" based on a non-linear scaling of the fees they have paid over the past few months (exact time frame TBD).

The developers have the ability to propose an upgrade using their customized `UpgradeCap`, but they cannot approve the upgrade themselves. When they propose an upgrade, it goes to the community for a vote. All players will be able to see the proposed new source code, review it for security issues or malicious behaviour, and vote on whether it should be deployed or not. The weight of a character's vote depends on the total fees that been paid for that character's jump permits, as noted above, ensuring that characters who use the FTA the most are given the most decision-making power.

This mechanism ensures that upgrades are possible if fixes or improvements are desired by the community, the community can vote on whether the changes are fair and logical and should be deployed, and "vote brigading" becomes more difficult as the non-linear scaling factor prevents purchases of exorbitantly large jump fees in order to increase vote weight (purchasing votes).

The implementation of this system can be seen [here](https://github.com/Internet-Spaceship-Enterprises/frontier-transit-authority/blob/main/contracts/fta/sources/upgrades/upgrades.move).

### Abandonware
To support long-term survival and use of the FTA, we must ensure that if the developers abandon the project for any reason, control automatically transfers to another party. We have planned a mechanism that automatically initiates a vote for a new owner of the `UpgradeCap` if the current developers have not proposed an update in 3 months. Voting will occur in the same way as with new deployments, with the same voting eligibility, allowing the community to select a new developer if the original developers abandon the project.