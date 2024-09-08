const HOOKS_COUNT_MASK: number = 0xF0000;
const HOOKS_BIT_MASK: number = 0x0FFFF;

const HOOKS_COUNT_MASK_SIZE: number = 4;
const HOOKS_BIT_MASK_SIZE: number = 16;

const BEFORE_INITIALIZE_BIT_SHIFT: number = (8 * HOOKS_COUNT_MASK_SIZE + 9 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;
const AFTER_INITIALIZE_BIT_SHIFT: number = (7 * HOOKS_COUNT_MASK_SIZE + 8 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;

const BEFORE_ADD_LIQUIDITY_BIT_SHIFT: number = (6 * HOOKS_COUNT_MASK_SIZE + 7 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;
const AFTER_ADD_LIQUIDITY_BIT_SHIFT: number = (5 * HOOKS_COUNT_MASK_SIZE + 6 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;

const BEFORE_REMOVE_LIQUIDITY_BIT_SHIFT: number = (4 * HOOKS_COUNT_MASK_SIZE + 5 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;
const AFTER_REMOVE_LIQUIDITY_BIT_SHIFT: number = (3 * HOOKS_COUNT_MASK_SIZE + 4 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;

const BEFORE_SWAP_BIT_SHIFT: number = (2 * HOOKS_COUNT_MASK_SIZE + 3 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;
const AFTER_SWAP_BIT_SHIFT: number = (1 * HOOKS_COUNT_MASK_SIZE + 2 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;

const BEFORE_DONATE_BIT_SHIFT: number = (0 * HOOKS_COUNT_MASK_SIZE + 1 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;
const AFTER_DONATE_BIT_SHIFT: number = 0;

const BEFORE_INITIALIZE_HOOK_FLAGS: bigint = BigInt(0xFFFFF) << BigInt(BEFORE_INITIALIZE_BIT_SHIFT);
const AFTER_INITIALIZE_HOOK_FLAGS: bigint = BigInt(0xFFFFF) << BigInt(AFTER_INITIALIZE_BIT_SHIFT);

const BEFORE_ADD_LIQUIDITY_HOOK_FLAGS: bigint = BigInt(0xFFFFF) << BigInt(BEFORE_ADD_LIQUIDITY_BIT_SHIFT);
const AFTER_ADD_LIQUIDITY_HOOK_FLAGS: bigint = BigInt(0xFFFFF) << BigInt(AFTER_ADD_LIQUIDITY_BIT_SHIFT);

const BEFORE_REMOVE_LIQUIDITY_HOOK_FLAGS: bigint = BigInt(0xFFFFF) << BigInt(BEFORE_REMOVE_LIQUIDITY_BIT_SHIFT);
const AFTER_REMOVE_LIQUIDITY_HOOK_FLAGS: bigint = BigInt(0xFFFFF) << BigInt(AFTER_REMOVE_LIQUIDITY_BIT_SHIFT);

const BEFORE_SWAP_HOOK_FLAGS: bigint = BigInt(0xFFFFF) << BigInt(BEFORE_SWAP_BIT_SHIFT);
const AFTER_SWAP_HOOK_FLAGS: bigint = BigInt(0xFFFFF) << BigInt(AFTER_SWAP_BIT_SHIFT);

const BEFORE_DONATE_HOOK_FLAGS: bigint = BigInt(0xFFFFF) << BigInt(BEFORE_DONATE_BIT_SHIFT);
const AFTER_DONATE_HOOK_FLAGS: bigint = BigInt(0xFFFFF) << BigInt(AFTER_DONATE_BIT_SHIFT);

const MAX_HOOKS_COUNT: number = HOOKS_BIT_MASK_SIZE;

type HookNames = 'beforeInitialize' | 'afterInitialize' | 'beforeAddLiquidity' | 'afterAddLiquidity' | 
                 'beforeRemoveLiquidity' | 'afterRemoveLiquidity' | 'beforeSwap' | 'afterSwap' | 
                 'beforeDonate' | 'afterDonate';


const HOOKS_MASKS: Record<HookNames, { flag: bigint, shift: number }>  = {
  beforeInitialize: { flag: BEFORE_INITIALIZE_HOOK_FLAGS, shift: BEFORE_INITIALIZE_BIT_SHIFT },
  afterInitialize: { flag: AFTER_INITIALIZE_HOOK_FLAGS, shift: AFTER_INITIALIZE_BIT_SHIFT },
  beforeAddLiquidity: { flag: BEFORE_ADD_LIQUIDITY_HOOK_FLAGS, shift: BEFORE_ADD_LIQUIDITY_BIT_SHIFT },
  afterAddLiquidity: { flag: AFTER_ADD_LIQUIDITY_HOOK_FLAGS, shift: AFTER_ADD_LIQUIDITY_BIT_SHIFT },
  beforeRemoveLiquidity: { flag: BEFORE_REMOVE_LIQUIDITY_HOOK_FLAGS, shift: BEFORE_REMOVE_LIQUIDITY_BIT_SHIFT },
  afterRemoveLiquidity: { flag: AFTER_REMOVE_LIQUIDITY_HOOK_FLAGS, shift: AFTER_REMOVE_LIQUIDITY_BIT_SHIFT },
  beforeSwap: { flag: BEFORE_SWAP_HOOK_FLAGS, shift: BEFORE_SWAP_BIT_SHIFT },
  afterSwap: { flag: AFTER_SWAP_HOOK_FLAGS, shift: AFTER_SWAP_BIT_SHIFT },
  beforeDonate: { flag: BEFORE_DONATE_HOOK_FLAGS, shift: BEFORE_DONATE_BIT_SHIFT },
  afterDonate: { flag: AFTER_DONATE_HOOK_FLAGS, shift: AFTER_DONATE_BIT_SHIFT }
};

function logActivatedHooks(newActivatedHooks: bigint) {
    const hookNames: HookNames[] = [
      'afterDonate',
      'beforeDonate',
      'afterSwap',
      'beforeSwap',
      'afterRemoveLiquidity',
      'beforeRemoveLiquidity',
      'afterAddLiquidity',
      'beforeAddLiquidity',
      'afterInitialize',
      'beforeInitialize'
    ];
  
    hookNames.forEach((hookName, index) => {
      const { shift } = HOOKS_MASKS[hookName];
      
      const interval = (newActivatedHooks >> BigInt(shift)) & 0xFFFFFn;
      const intervalString = interval.toString(2).padStart(20, '0');

      console.log(`${intervalString}: ${hookName}`);
    });
  }

function countActivatedHooks(hooksFlags: number): number {
    let count = 0;
    for (let i = 0; i < 16; i++) {
      if ((hooksFlags & (1 << i)) !== 0) {
        count++;
      }
    }
    return count;
  }
  
  function activateHooks(hooksConfig: Record<string, boolean>, currentActivatedHooks: bigint, hookId: number): bigint {
    let newActivatedHooks = currentActivatedHooks;
  
    Object.keys(HOOKS_MASKS).forEach((hookName) => {
      const { shift } = HOOKS_MASKS[hookName as keyof typeof HOOKS_MASKS];
  
      const currentInterval = (newActivatedHooks >> BigInt(shift)) & 0xFFFFFn;
      const currentHooksCount = Number((currentInterval >> 16n) & 0xFn);
      let currentHooksFlags = Number(currentInterval & 0xFFFFn);
  
      const hookPosition = 15 - hookId;
  
      if (hooksConfig[hookName as keyof typeof hooksConfig]) {
        currentHooksFlags |= (1 << hookPosition);
      } else {
        currentHooksFlags &= ~(1 << hookPosition);
      }
  
      const newHooksCount = countActivatedHooks(currentHooksFlags);
      const newInterval = (newHooksCount << 16) | currentHooksFlags;
      newActivatedHooks = (newActivatedHooks & ~(BigInt(0xFFFFF) << BigInt(shift))) | (BigInt(newInterval) << BigInt(shift));
    });
  
    return newActivatedHooks;
  }
  

  
  const currentActivatedHooks: bigint = BigInt("0x0");
  const hooksConfig = {
    beforeInitialize: true,
    afterInitialize: false,
    beforeAddLiquidity: false,
    afterAddLiquidity: false,
    beforeRemoveLiquidity: false,
    afterRemoveLiquidity: false,
    beforeSwap: true,
    afterSwap: true,
    beforeDonate: false,
    afterDonate: false
  };
  
  let hookId = 0;
  const newActivatedHooks = activateHooks(hooksConfig, currentActivatedHooks, hookId);

  console.log(newActivatedHooks.toString(2));
  console.log(newActivatedHooks);
//   logActivatedHooks(newActivatedHooks);