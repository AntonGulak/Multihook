# Problem
There are numerous hooks emerging in the market that can be integrated into Uniswap v4 pools. But what are the chances that a user will find a hook that fits 100% of their needs? For example, I might want to launch an LBP pool with a whitelist that operates only during exchange working hours. After 7 days, I might want to convert this pool into a regular one (on the LBP end date). The likelihood of finding a single hook that covers all these needs is close to zero. This forces me to hire a developer to combine the hooks into one contract. And even after that, no one will fully trust the code without an audit, even if all the individual hooks used are audited.

# Solution
A **Hook Adapter** that allows for combining and configuring hooks. It enables adding up to **16 hooks** into a single adapter, and even allows changing the combination during the pool's operation (with a time lock and, for example, through a DAO). Moreover, it lets users choose the order of hooks for each method or even remove a hook from a selected method.

The operation is simple – when the PoolManager calls the MultiHook, it processes all the configured hooks in the specified sequence, and connected hooks provide feedback to the PoolManager via a fallback on the MultiHook.

Furthermore, most existing hooks require no code modifications. You simply need to specify the MultiHook address as the PoolManager in the constructor parameters!

# Incompatibilities at the moment:
1. If a hook uses the PoolManager address as `msg.sender`.
2. If a hook requires a direct call, bypassing the MultiHook (e.g., for asset deposits). The solution is simple – allow all connected hooks to send a request through the fallback, but security concerns need further exploration.
