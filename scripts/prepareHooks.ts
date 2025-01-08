/******************************************************
 * 1) HOOK ACTIVATION BITMASK (20 bits per method)
 *****************************************************/
/**
 * Each method has a 20-bit slice in a global bigint (`activatedHooks`):
 *  - The top 4 bits store how many hooks are active for that method.
 *  - The bottom 16 bits store which hook IDs (0..15) are active.
 *
 * Example:
 *   If "afterSwap" has 2 active hooks (hookId=0 and hookId=1),
 *   then the top 4 bits = 2 (0b0010), and the bottom 16 bits might be
 *   0b1100000000000000 (bits #15 and #14 set).
 */

// Let's assume we have EXACTLY 3 hooks total, so valid queue positions = 0..2.
const TOTAL_HOOKS = 3;

// 4 bits for the count, 16 bits for flags
const HOOKS_COUNT_MASK: number = 0xF0000;
const HOOKS_BIT_MASK:   number = 0x0FFFF;

const HOOKS_COUNT_MASK_SIZE: number = 4;
const HOOKS_BIT_MASK_SIZE:   number = 16;
const MAX_HOOKS_COUNT: number = HOOKS_BIT_MASK_SIZE; // 16 possible hook IDs, but we only *use* 3 in this example

// Each method occupies a unique 20-bit interval in the big integer:
const BEFORE_INITIALIZE_BIT_SHIFT:   number = (8 * HOOKS_COUNT_MASK_SIZE + 9 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE; 
const AFTER_INITIALIZE_BIT_SHIFT:    number = (7 * HOOKS_COUNT_MASK_SIZE + 8 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;
const BEFORE_ADD_LIQUIDITY_BIT_SHIFT:  number = (6 * HOOKS_COUNT_MASK_SIZE + 7 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;
const AFTER_ADD_LIQUIDITY_BIT_SHIFT:   number = (5 * HOOKS_COUNT_MASK_SIZE + 6 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;
const BEFORE_REMOVE_LIQUIDITY_BIT_SHIFT: number = (4 * HOOKS_COUNT_MASK_SIZE + 5 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;
const AFTER_REMOVE_LIQUIDITY_BIT_SHIFT:  number = (3 * HOOKS_COUNT_MASK_SIZE + 4 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;
const BEFORE_SWAP_BIT_SHIFT: number = (2 * HOOKS_COUNT_MASK_SIZE + 3 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;
const AFTER_SWAP_BIT_SHIFT:  number = (1 * HOOKS_COUNT_MASK_SIZE + 2 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;
const BEFORE_DONATE_BIT_SHIFT: number = (0 * HOOKS_COUNT_MASK_SIZE + 1 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;
const AFTER_DONATE_BIT_SHIFT:  number = 0; // last slice

type HookMethod =
  | 'beforeInitialize'
  | 'afterInitialize'
  | 'beforeAddLiquidity'
  | 'afterAddLiquidity'
  | 'beforeRemoveLiquidity'
  | 'afterRemoveLiquidity'
  | 'beforeSwap'
  | 'afterSwap'
  | 'beforeDonate'
  | 'afterDonate';

/**
 * Maps each HookMethod to its 20-bit shift inside `activatedHooks`.
 */
const HOOK_BITMASK_SHIFTS: Record<HookMethod, number> = {
  beforeInitialize:      BEFORE_INITIALIZE_BIT_SHIFT,
  afterInitialize:       AFTER_INITIALIZE_BIT_SHIFT,
  beforeAddLiquidity:    BEFORE_ADD_LIQUIDITY_BIT_SHIFT,
  afterAddLiquidity:     AFTER_ADD_LIQUIDITY_BIT_SHIFT,
  beforeRemoveLiquidity: BEFORE_REMOVE_LIQUIDITY_BIT_SHIFT,
  afterRemoveLiquidity:  AFTER_REMOVE_LIQUIDITY_BIT_SHIFT,
  beforeSwap:            BEFORE_SWAP_BIT_SHIFT,
  afterSwap:             AFTER_SWAP_BIT_SHIFT,
  beforeDonate:          BEFORE_DONATE_BIT_SHIFT,
  afterDonate:           AFTER_DONATE_BIT_SHIFT,
};

/**
 * Counts how many bits are set to 1 in a 16-bit integer (flags).
 */
function countActivatedHooks(flags16: number): number {
  let count = 0;
  for (let i = 0; i < 16; i++) {
    if ((flags16 & (1 << i)) !== 0) {
      count++;
    }
  }
  return count;
}

/**
 * Activates or deactivates a method for a specific hookId in `activatedHooks`.
 * 
 * @param hooksConfig   e.g. { afterSwap: true, beforeSwap: false, ... }
 * @param currentHooks  the current bigInt bitmask
 * @param hookId        which bit (0..15) to set/unset
 */
function activateHooks(
  hooksConfig: Record<HookMethod, boolean>,
  currentHooks: bigint,
  hookId: number
): bigint {
  let newHooks = currentHooks;

  // For each method, extract its 20-bit slice, set/unset the bit, then combine back.
  (Object.keys(HOOK_BITMASK_SHIFTS) as HookMethod[]).forEach((method) => {
    const shift = HOOK_BITMASK_SHIFTS[method];
    const interval20 = (newHooks >> BigInt(shift)) & BigInt(0xFFFFF);

    // Lower 16 bits -> flags, top 4 bits -> count
    let flags16 = Number(interval20 & BigInt(0xFFFF));
    const bitPos = 15 - hookId;

    if (hooksConfig[method]) {
      flags16 |=  (1 << bitPos);
    } else {
      flags16 &= ~(1 << bitPos);
    }

    // Recount how many bits are set
    const newCount = countActivatedHooks(flags16);
    const newInterval20 = (newCount << 16) | flags16;

    // Clear old 20 bits, then put new 20 bits
    newHooks =
      (newHooks & ~(BigInt(0xFFFFF) << BigInt(shift))) |
      (BigInt(newInterval20) << BigInt(shift));
  });

  return newHooks;
}

/**
 * Checks if a given `method` is active for `hookId` in `activatedHooks`.
 */
function isMethodActiveForHook(
  activatedHooks: bigint,
  hookId: number,
  method: HookMethod
): boolean {
  const shift = HOOK_BITMASK_SHIFTS[method];
  const interval20 = (activatedHooks >> BigInt(shift)) & BigInt(0xFFFFF);
  const flags16 = Number(interval20 & BigInt(0xFFFF));

  const bitPos = 15 - hookId;
  return (flags16 & (1 << bitPos)) !== 0;
}

/**
 * Logs which hooks are active for each method in `activatedHooks`.
 */
function logActivatedHooks(activatedHooks: bigint) {
  const methods: HookMethod[] = [
    'afterDonate',
    'beforeDonate',
    'afterSwap',
    'beforeSwap',
    'afterRemoveLiquidity',
    'beforeRemoveLiquidity',
    'afterAddLiquidity',
    'beforeAddLiquidity',
    'afterInitialize',
    'beforeInitialize',
  ];

  methods.forEach((m) => {
    const shift = HOOK_BITMASK_SHIFTS[m];
    const interval20 = (activatedHooks >> BigInt(shift)) & BigInt(0xFFFFF);

    const count4 = Number((interval20 >> BigInt(16)) & BigInt(0xF));
    const flags16 = Number(interval20 & BigInt(0xFFFF));

    const flagsBin = flags16.toString(2).padStart(16, '0');
    if (count4 === 0) {
      console.log(`${m}: none`);
    } else {
      console.log(`${m}: ${count4} hook(s), flags=0b${flagsBin}`);
    }
  });
}


/******************************************************
 * 2) HOOK QUEUE ORDER (4 bits per method in hookQueue)
 *****************************************************/
/**
 * In the contract, each hook's "hookQueue" (uint96) indicates the 
 * order for each method. Each method uses 4 bits => 0..15, 
 * but we only allow 0..(TOTAL_HOOKS-1) in this example.
 */

const BEFORE_INITIALIZE_QUEUE_BIT_SHIFT     = 9 * HOOKS_COUNT_MASK_SIZE; // =36
const AFTER_INITIALIZE_QUEUE_BIT_SHIFT      = 8 * HOOKS_COUNT_MASK_SIZE; // =32
const BEFORE_ADD_LIQUIDITY_QUEUE_BIT_SHIFT  = 7 * HOOKS_COUNT_MASK_SIZE; // =28
const AFTER_ADD_LIQUIDITY_QUEUE_BIT_SHIFT   = 6 * HOOKS_COUNT_MASK_SIZE; // =24
const BEFORE_REMOVE_LIQUIDITY_QUEUE_BIT_SHIFT = 5 * HOOKS_COUNT_MASK_SIZE; // =20
const AFTER_REMOVE_LIQUIDITY_QUEUE_BIT_SHIFT  = 4 * HOOKS_COUNT_MASK_SIZE; // =16
const BEFORE_SWAP_QUEUE_BIT_SHIFT           = 3 * HOOKS_COUNT_MASK_SIZE; // =12
const AFTER_SWAP_QUEUE_BIT_SHIFT            = 2 * HOOKS_COUNT_MASK_SIZE; // =8
const BEFORE_DONATE_QUEUE_BIT_SHIFT         = 1 * HOOKS_COUNT_MASK_SIZE; // =4
const AFTER_DONATE_QUEUE_BIT_SHIFT          = 0;                         // =0

/**
 * Mapping each method to its 4-bit shift inside `hookQueue`.
 */
const HOOK_QUEUE_SHIFTS: Record<HookMethod, number> = {
  beforeInitialize:      BEFORE_INITIALIZE_QUEUE_BIT_SHIFT,
  afterInitialize:       AFTER_INITIALIZE_QUEUE_BIT_SHIFT,
  beforeAddLiquidity:    BEFORE_ADD_LIQUIDITY_QUEUE_BIT_SHIFT,
  afterAddLiquidity:     AFTER_ADD_LIQUIDITY_QUEUE_BIT_SHIFT,
  beforeRemoveLiquidity: BEFORE_REMOVE_LIQUIDITY_QUEUE_BIT_SHIFT,
  afterRemoveLiquidity:  AFTER_REMOVE_LIQUIDITY_QUEUE_BIT_SHIFT,
  beforeSwap:            BEFORE_SWAP_QUEUE_BIT_SHIFT,
  afterSwap:             AFTER_SWAP_QUEUE_BIT_SHIFT,
  beforeDonate:          BEFORE_DONATE_QUEUE_BIT_SHIFT,
  afterDonate:           AFTER_DONATE_QUEUE_BIT_SHIFT,
};

/**
 * Sets the queue position for `method` in a hook's `hookQueue`.
 * Allowed positions = 0..(TOTAL_HOOKS-1).
 */
function setHookQueuePosition(
  currentQueue: bigint,
  method: HookMethod,
  position: number
): bigint {
  if (position < 0 || position >= TOTAL_HOOKS) {
    throw new Error(
      `Invalid queue position=${position}. 
       Must be in [0..${TOTAL_HOOKS - 1}] since we only have ${TOTAL_HOOKS} hooks.`
    );
  }
  const shift = HOOK_QUEUE_SHIFTS[method];
  // Clear old 4 bits
  const mask = BigInt(0xF) << BigInt(shift);
  let newQueue = currentQueue & ~mask;
  // Set new 4 bits
  newQueue |= (BigInt(position) & BigInt(0xF)) << BigInt(shift);
  return newQueue;
}

/**
 * Gets the queue position (0..(TOTAL_HOOKS-1)) for `method` in a hook's queue.
 */
function getHookQueuePosition(currentQueue: bigint, method: HookMethod): number {
  const shift = HOOK_QUEUE_SHIFTS[method];
  return Number((currentQueue >> BigInt(shift)) & BigInt(0xF));
}

/**
 * Logs each method's queue position from a given hookQueue BigInt,
 * plus prints the numeric value in hex/dec.
 */
function logHookQueue(hookQueue: bigint, hookId: number) {
  console.log(`\nHookId=${hookId} => hookQueue=0x${hookQueue.toString(16)} (dec=${hookQueue.toString(10)})`);
  const methods: HookMethod[] = [
    'afterDonate',
    'beforeDonate',
    'afterSwap',
    'beforeSwap',
    'afterRemoveLiquidity',
    'beforeRemoveLiquidity',
    'afterAddLiquidity',
    'beforeAddLiquidity',
    'afterInitialize',
    'beforeInitialize',
  ];
  methods.forEach((m) => {
    const pos = getHookQueuePosition(hookQueue, m);
    console.log(`   ${m}: queuePos=${pos}`);
  });
}

/******************************************************
 * 3) VALIDATION: no collisions in *active* methods
 *****************************************************/
/**
 * For each method, we only validate queue collisions among hooks
 * that *actually have the method active*. 
 * Also, each queue position must be unique for these active hooks.
 */
function validateHookQueuesNoCollisions(
  activatedHooks: bigint,
  hookQueues: Record<number, bigint>
) {
  const hookIds = Object.keys(hookQueues).map(Number);

  const allMethods: HookMethod[] = [
    'beforeInitialize',
    'afterInitialize',
    'beforeAddLiquidity',
    'afterAddLiquidity',
    'beforeRemoveLiquidity',
    'afterRemoveLiquidity',
    'beforeSwap',
    'afterSwap',
    'beforeDonate',
    'afterDonate',
  ];

  for (const method of allMethods) {
    // We'll gather positions only for hooks that have this method active.
    const usedPositions = new Set<number>();

    for (const hId of hookIds) {
      if (isMethodActiveForHook(activatedHooks, hId, method)) {
        const pos = getHookQueuePosition(hookQueues[hId], method);
        if (usedPositions.has(pos)) {
          throw new Error(
            `Queue collision: method=${method}, position=${pos} 
             is used by more than one hook (among active hooks).`
          );
        }
        usedPositions.add(pos);
      }
    }
  }
  console.log("Queue validation passed: no collisions among active methods.\n");
}

/******************************************************
 * 4) EXAMPLE USAGE
 *****************************************************/
/**
 * We'll define 3 hooks (hookId=0..2):
 *   - Each with different methods enabled (activateHooks).
 *   - We'll assign queue positions from 0..2. (No bigger than 2!)
 *   - Validate that no collisions occur among active methods.
 */

function main() {
  // Start with no methods active
  let activatedHooksGlobal: bigint = BigInt(0);
  const hookQueues: Record<number, bigint> = {};

  console.log(`\n=== We have a total of ${TOTAL_HOOKS} hooks. Queue positions = 0..${TOTAL_HOOKS - 1} ===\n`);

  // =============== Hook #0 ===============
  console.log("=== Step 1: Activate hooks for hookId=0 ===");
  const configHook0: Record<HookMethod, boolean> = {
    beforeInitialize: false,
    afterInitialize: false,
    beforeAddLiquidity: false,
    afterAddLiquidity: false,
    beforeRemoveLiquidity: false,
    afterRemoveLiquidity: true,  // active
    beforeSwap: true,            // active
    afterSwap: true,             // active
    beforeDonate: false,
    afterDonate: false,
  };
  activatedHooksGlobal = activateHooks(configHook0, activatedHooksGlobal, 0);

  hookQueues[0] = BigInt(0);
  // Allowed positions = 0..2
  hookQueues[0] = setHookQueuePosition(hookQueues[0], "afterRemoveLiquidity", 0);
  hookQueues[0] = setHookQueuePosition(hookQueues[0], "beforeSwap", 1);
  hookQueues[0] = setHookQueuePosition(hookQueues[0], "afterSwap", 2);

  logHookQueue(hookQueues[0], 0);

  // =============== Hook #1 ===============
  console.log("\n=== Step 2: Activate hooks for hookId=1 ===");
  const configHook1: Record<HookMethod, boolean> = {
    beforeInitialize: true,
    afterInitialize: false,
    beforeAddLiquidity: false,
    afterAddLiquidity: false,
    beforeRemoveLiquidity: false,
    afterRemoveLiquidity: false,
    beforeSwap: false,
    afterSwap: true,
    beforeDonate: false,
    afterDonate: true,
  };
  activatedHooksGlobal = activateHooks(configHook1, activatedHooksGlobal, 1);

  hookQueues[1] = BigInt(0);
  hookQueues[1] = setHookQueuePosition(hookQueues[1], "beforeInitialize", 0);
  hookQueues[1] = setHookQueuePosition(hookQueues[1], "afterSwap", 1);
  hookQueues[1] = setHookQueuePosition(hookQueues[1], "afterDonate", 2);

  logHookQueue(hookQueues[1], 1);

  // =============== Hook #2 ===============
  console.log("\n=== Step 3: Activate hooks for hookId=2 ===");
  const configHook2: Record<HookMethod, boolean> = {
    beforeInitialize: false,
    afterInitialize: false,
    beforeAddLiquidity: true,
    afterAddLiquidity: true,
    beforeRemoveLiquidity: false,
    afterRemoveLiquidity: false,
    beforeSwap: false,
    afterSwap: false,
    beforeDonate: true,
    afterDonate: false,
  };
  activatedHooksGlobal = activateHooks(configHook2, activatedHooksGlobal, 2);

  hookQueues[2] = BigInt(0);
  hookQueues[2] = setHookQueuePosition(hookQueues[2], "beforeAddLiquidity", 0);
  hookQueues[2] = setHookQueuePosition(hookQueues[2], "afterAddLiquidity", 1);
  hookQueues[2] = setHookQueuePosition(hookQueues[2], "beforeDonate", 2);

  logHookQueue(hookQueues[2], 2);

  // Validate collisions among *active* methods only
  validateHookQueuesNoCollisions(activatedHooksGlobal, hookQueues);

  // Print final
  console.log("\n=== ActivatedHooks BigInt ===");
  console.log("Decimal:", activatedHooksGlobal.toString(10));
  console.log("Hex:    0x" + activatedHooksGlobal.toString(16));

  console.log("\nDetailed activation:");
  logActivatedHooks(activatedHooksGlobal);

  console.log("\nAll done!\n");
}

// Entry point
main();

/******************************************************
 * End of script
 *****************************************************/
