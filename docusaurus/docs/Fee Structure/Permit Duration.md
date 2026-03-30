---
sidebar_position: 5
---

By default, jump permits are valid for a brief period of time (currently 2 minutes). This is enough to allow the user to open the gate's dApp, purchase the permit, and use it to jump.

There are cases, though, where players or tribes may wish to purchase jump permits of a longer duration to allow for large operations where the exact time of execution is unknown. FTA supports this by allowing a longer jump permit duration in exchange for a higher fee.

FTA has a hardcoded (constant) value for the minimum (default) duration, the maximum permitted duration, and the fee scaling factor. The jump fee is linearly scaled; for example, if the default/minimum duration is 2 minutes, the maximum duration is 1 day, and the max duration scaling factor is 20, then a permit that is valid for 12 hours (roughly half way between the minimum and maximum durations) would cost approximately 10x more than the standard fee.

The expiry times on jump permits are intended to ensure that users do not rely on consistent availability of FTA gates for an extended period of time. Gates can go offline due to destruction, fuel shortage, etc., so we want people to plan for short-term permits that are issued just-in-time.
