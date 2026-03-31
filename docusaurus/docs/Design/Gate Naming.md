---
sidebar_position: 4
---

When gates are registered with the FTA and ownership is transferred, their metadata is automatically updated as part of the transaction to ensure consistency across FTA infrastructure. 

Gates are named in the format `Frontier Transit Authority - [SOLAR_SYSTEM_ID] [GREEK_LETTERS]`, where `GREEK_LETTERS` are three Greek letters that are selected automatically based on the specific coordinates of the gate (think of it as a Greek hashing system). This approach ensures that even when there are multiple FTA gates in one system, each is uniquely named. For example, a gate in `O5P-545` might be named `Frontier Transit Authority - 30014210 Eta Pi Lambda`. The name of the system where the linked gate resides is automatically appended in-game, so the name visible to the player might be `Frontier Transit Authority - 30014210 Eta Pi Lambda (AKF-K95)`.

Presently, solar system names are not available on-chain and there is no way to include the system name in the gate name while guaranteeing that the system name is correct (i.e. not being susceptible to a bad actor providing the wrong system name in a transaction). We are looking into ways to circumvent this limitation so we can include the system name instead of the system ID in the gate name. It appears that CCP intends to support this by including signatures in the API responses so they can be verified on-chain, but those are currently POD signatures (hold-over from the Solidity days) and are not verifiable in Sui Move.