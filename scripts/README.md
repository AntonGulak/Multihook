# Multihook Configuration & Queue Script

This repository provides a **TypeScript** script for managing hooks in a Uniswap v4-like system. Each hook method (e.g. `beforeSwap`, `afterSwap`, etc.) has two key data points:

1. **Activation Bitmask** (20 bits per method)  
   - Stored in a single global `bigint` (`activatedHooksGlobal`).  
   - **Top 4 bits**: how many hooks are active for this method.  
   - **Bottom 16 bits**: which hook IDs (`0..15`) are active.

2. **Queue Positions** (`hookQueue`)  
   - For each **individual** hook (identified by `hookId`), we store a `hookQueue` (a `BigInt` that mimics a `uint96` in Solidity).  
   - Each method is allocated **4 bits** to define the execution order.  
   - In this script, we limit valid positions to `0..(TOTAL_HOOKS - 1)`.  
   - We also ensure that **no two hooks** share the **same** position for a method **if** that method is **active** on both hooks.

## How It Works

### 1) Activating Methods

Use the function `activateHooks(hooksConfig, currentHooks, hookId)` to enable or disable each method for a particular `hookId`. Internally:

- The script iterates over all 10 known methods (`beforeSwap`, `afterSwap`, etc.).
- For each method, it extracts the **20-bit slice** from `currentHooks`.
- It sets or unsets the bit `(15 - hookId)` if `hooksConfig[method]` is `true` or `false`.
- It recalculates the **top 4 bits** for the new total of active bits in the slice.
- It merges back into the main `bigint` (`activatedHooksGlobal`).

### 2) Queue Positions

Each hook has its own `hookQueue`. We manage it with:
- `setHookQueuePosition(hookQueue, method, position)`  
  - **position** must be within `0..(TOTAL_HOOKS - 1)`.  
  - The script throws an error if you try a higher position than allowed.
- `getHookQueuePosition(hookQueue, method)`  
  - Reads the 4-bit queue value for a given `method`.
- `logHookQueue(hookQueue, hookId)`  
  - Prints the `hookQueue` in decimal/hex and enumerates positions for each method.

### 3) Collision Validation

We call `validateHookQueuesNoCollisions(activatedHooksGlobal, hookQueues)` to confirm:

- **No two hooks** occupy the same queue position **for any method** that is **active** on both hooks.
- Methods that are **not** active for a hook do **not** trigger collisions.

This ensures that if method `beforeSwap` is active on Hook #0 and Hook #1, they cannot share the same position.

## Example

```ts
// 1) We declare a fixed number of hooks, e.g. TOTAL_HOOKS = 3
//    so valid queue positions are 0..2

// 2) Start with nothing activated
let activatedHooksGlobal: bigint = BigInt(0);
let hookQueues: Record<number, bigint> = {};

// 3) Activate certain methods for hookId=0
const configHook0 = {
  beforeSwap: true,
  afterSwap: true,
  afterRemoveLiquidity: true,
  // other methods = false
};
activatedHooksGlobal = activateHooks(configHook0, activatedHooksGlobal, 0);

// 4) Assign queue positions for these methods (all must be <= 2)
hookQueues[0] = BigInt(0);
hookQueues[0] = setHookQueuePosition(hookQueues[0], "beforeSwap", 0);
hookQueues[0] = setHookQueuePosition(hookQueues[0], "afterSwap", 1);
hookQueues[0] = setHookQueuePosition(hookQueues[0], "afterRemoveLiquidity", 2);

// 5) Inspect final results
console.log("activatedHooksGlobal (hex) =", activatedHooksGlobal.toString(16));
logActivatedHooks(activatedHooksGlobal);

console.log("\nHook #0 queue:");
logHookQueue(hookQueues[0], 0);

// 6) (Optional) Validate collisions among multiple hooks
//    if we add more hooks, we can call:
validateHookQueuesNoCollisions(activatedHooksGlobal, hookQueues);
