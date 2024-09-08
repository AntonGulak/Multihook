// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";

import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";


import {BeforeSwapDelta, toBeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {BaseHook, BalanceDelta} from "v4-periphery/src/base/hooks/BaseHook.sol";

import {HookLib, Hook, HookPacked} from "./HookLib.sol";

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import "forge-std/console.sol";

//hooks sload to tload !!! TODO:
//fallback ==> poolmanager proxy


//TODO:
interface IUnlockCallback {
    function unlockCallback(bytes calldata data) external returns (bytes memory);
}


error MaxHooksCountExceeded();
error ZeroAddress();

contract Multihook is BaseHook, Ownable2Step {
    using CurrencySettler for Currency;
    using HookLib for Hook[];

    uint24 public constant HOOKS_COUNT_MASK = 0xF0000;
    uint24 public constant HOOKS_BIT_MASK = 0x0FFFF;

    uint8 public constant HOOKS_COUNT_MASK_SIZE = 4;
    uint8 public constant HOOKS_BIT_MASK_SIZE = 16;

    uint8 public constant BEFORE_INITIALIZE_BIT_SHIFT = (8 * HOOKS_COUNT_MASK_SIZE + 9 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;
    uint8 public constant AFTER_INITIALIZE_BIT_SHIFT= (7 * HOOKS_COUNT_MASK_SIZE + 8 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE; 

    uint8 public constant BEFORE_ADD_LIQUIDITY_BIT_SHIFT = (6 * HOOKS_COUNT_MASK_SIZE + 7 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE; 
    uint8 public constant AFTER_ADD_LIQUIDITY_BIT_SHIFT = (5 * HOOKS_COUNT_MASK_SIZE + 6 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;

    uint8 public constant BEFORE_REMOVE_LIQUIDITY_BIT_SHIFT = (4 * HOOKS_COUNT_MASK_SIZE + 5 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;
    uint8 public constant AFTER_REMOVE_LIQUIDITY_BIT_SHIFT = (3 * HOOKS_COUNT_MASK_SIZE + 4 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;

    uint8 public constant BEFORE_SWAP_BIT_SHIFT = (2 * HOOKS_COUNT_MASK_SIZE + 3 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;
    uint8 public constant AFTER_SWAP_BIT_SHIFT = (1 * HOOKS_COUNT_MASK_SIZE + 2 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE; 

    uint8 public constant BEFORE_DONATE_BIT_SHIFT = (0 * HOOKS_COUNT_MASK_SIZE + 1 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE;
    uint8 public constant AFTER_DONATE_BIT_SHIFT = 0;

    //4 бит под количество битов, 16 бит отрезок под флаги активных хуков 
    uint256 public constant BEFORE_INITIALIZE_HOOK_FLAGS = 0xFFFFF << BEFORE_INITIALIZE_BIT_SHIFT;
    uint256 public constant AFTER_INITIALIZE_HOOK_FLAGS = 0xFFFFF << AFTER_INITIALIZE_BIT_SHIFT; 

    uint256 public constant BEFORE_ADD_LIQUIDITY_HOOK_FLAGS = 0xFFFFF << BEFORE_ADD_LIQUIDITY_BIT_SHIFT; 
    uint256 public constant AFTER_ADD_LIQUIDITY_HOOK_FLAGS = 0xFFFFF << AFTER_ADD_LIQUIDITY_BIT_SHIFT;

    uint256 public constant BEFORE_REMOVE_LIQUIDITY_HOOK_FLAGS = 0xFFFFF << BEFORE_REMOVE_LIQUIDITY_BIT_SHIFT;
    uint256 public constant AFTER_REMOVE_LIQUIDITY_HOOK_FLAGS = 0xFFFFF << AFTER_REMOVE_LIQUIDITY_BIT_SHIFT;

    uint256 public constant BEFORE_SWAP_HOOK_FLAGS = 0xFFFFF << BEFORE_SWAP_BIT_SHIFT;
    uint256 public constant AFTER_SWAP_HOOK_FLAGS = 0xFFFFF << AFTER_SWAP_BIT_SHIFT; 

    uint256 public constant BEFORE_DONATE_HOOK_FLAGS = 0xFFFFF << BEFORE_DONATE_BIT_SHIFT;
    uint256 public constant AFTER_DONATE_HOOK_FLAGS = 0xFFFFF << AFTER_DONATE_BIT_SHIFT;

    uint8 public constant MAX_HOOKS_COUNT = HOOKS_BIT_MASK_SIZE;

    uint256 public activatedHooks;

    Hook[] public hooks;
    Hook[] public pendingHooks;
    
    constructor(
        IPoolManager poolManager,
        Hook[] memory initHooks,
        uint256 initActivatedHooks,
        address manager
    ) BaseHook(poolManager) Ownable(manager) {
       _setHooks(initHooks, hooks, initActivatedHooks);
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: true,
                afterInitialize: true,
                beforeAddLiquidity: true, 
                afterAddLiquidity: true,
                beforeRemoveLiquidity: true,
                afterRemoveLiquidity: true,
                beforeSwap: true, 
                afterSwap: true,
                beforeDonate: true,
                afterDonate: true,
                beforeSwapReturnDelta: true,
                afterSwapReturnDelta: true,
                afterAddLiquidityReturnDelta: true,
                afterRemoveLiquidityReturnDelta: true
            });
    }

    function beforeInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        bytes calldata hookData
    ) external override returns (bytes4) {
        Hook[] memory hooksMem = getActivatedHooks(activatedHooks, BEFORE_INITIALIZE_HOOK_FLAGS, BEFORE_INITIALIZE_BIT_SHIFT);
        hooksMem.executeBeforeInitialize(sender, key, sqrtPriceX96, hookData);
        return BaseHook.beforeInitialize.selector;
    }

    function afterInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 tick,
        bytes calldata hookData
    ) external override returns (bytes4) {
        Hook[] memory hooksMem = getActivatedHooks(activatedHooks, AFTER_INITIALIZE_HOOK_FLAGS, AFTER_INITIALIZE_BIT_SHIFT);
        hooksMem.executeAfterInitialize(sender, key, sqrtPriceX96, tick, hookData);
        return BaseHook.afterInitialize.selector;
    }

    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    )
        external
        override
        returns (bytes4)
    {
        Hook[] memory hooksMem = getActivatedHooks(activatedHooks, BEFORE_ADD_LIQUIDITY_HOOK_FLAGS, BEFORE_ADD_LIQUIDITY_BIT_SHIFT);
        hooksMem.executeBeforeAddLiquidity(sender, key, params, hookData);
        return BaseHook.beforeAddLiquidity.selector;
    }

    
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        Hook[] memory hooksMem = getActivatedHooks(activatedHooks, BEFORE_REMOVE_LIQUIDITY_HOOK_FLAGS, BEFORE_REMOVE_LIQUIDITY_BIT_SHIFT);
        hooksMem.executeBeforeRemoveLiquidity(sender, key, params, hookData);
        return BaseHook.beforeRemoveLiquidity.selector;
    }

    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        Hook[] memory hooksMem = getActivatedHooks(activatedHooks, AFTER_ADD_LIQUIDITY_HOOK_FLAGS, AFTER_ADD_LIQUIDITY_BIT_SHIFT);
        delta = hooksMem.executeAfterAddLiquidity(sender, key, params, delta, hookData);
        return (BaseHook.afterAddLiquidity.selector, delta);
    }

    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        Hook[] memory hooksMem = getActivatedHooks(activatedHooks, AFTER_REMOVE_LIQUIDITY_HOOK_FLAGS, AFTER_REMOVE_LIQUIDITY_BIT_SHIFT);
        delta = hooksMem.executeAfterAddLiquidity(sender, key, params, delta, hookData);
        return (BaseHook.afterRemoveLiquidity.selector, delta);
    }

     function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
        Hook[] memory hooksMem = getActivatedHooks(activatedHooks, BEFORE_SWAP_HOOK_FLAGS, BEFORE_SWAP_BIT_SHIFT);
        (BeforeSwapDelta delta, uint24 fee) = hooksMem.executeBeforeSwap(sender, key, params, hookData);
        return (BaseHook.beforeSwap.selector, delta, fee);
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta, 
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        Hook[] memory hooksMem = getActivatedHooks(activatedHooks, AFTER_SWAP_HOOK_FLAGS, AFTER_SWAP_BIT_SHIFT);
        int128 deltaUnspecified = hooksMem.executeAfterSwap(sender, key, params, delta, hookData);
        return (BaseHook.afterSwap.selector, deltaUnspecified);
    }

    function beforeDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external override returns (bytes4) {
        Hook[] memory hooksMem = getActivatedHooks(activatedHooks, BEFORE_DONATE_HOOK_FLAGS, BEFORE_DONATE_BIT_SHIFT);
        hooksMem.executeBeforeDonate(sender, key, amount0, amount1, hookData);
        return (BaseHook.beforeDonate.selector);
    }

    function afterDonate( 
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    )
        external
        override
        returns (bytes4)
    {
        Hook[] memory hooksMem = getActivatedHooks(activatedHooks, AFTER_DONATE_HOOK_FLAGS, AFTER_DONATE_BIT_SHIFT);
        hooksMem.executeAfterDonate(sender, key, amount0, amount1, hookData);
        return (BaseHook.afterDonate.selector);
    }

    //rewrite SafeCallback
    function unlockCallback(bytes calldata data) external onlyByPoolManager override returns (bytes memory) {
        IUnlockCallback hook = IUnlockCallback(HookLib.tloadPool());
        return hook.unlockCallback(data);
    }

    fallback() external {
        if (msg.sender == HookLib.tloadPool()) {
           _callOptionalReturn(address(poolManager), msg.data);
        } else {
            revert("fallback"); //TODO
        }
    }
    
    //TODO: remove to lib
    function getActivatedHooks(uint256 _activatedHooks, uint256 hookFlags, uint8 bitShift) public view returns (Hook[] memory) {
        uint24 hook_info = uint24((_activatedHooks & hookFlags ) >> bitShift);

        uint24 hooks_counts = (hook_info & HOOKS_COUNT_MASK) >> HOOKS_BIT_MASK_SIZE;
        uint16 hooks_flags = uint16(hook_info & HOOKS_BIT_MASK);

        Hook[] memory selectedHooks = new Hook[](hooks_counts);
        Hook[] memory hooksMem = hooks;

        uint256 index;
        //TODO check: for (uint8 i = 0; i < hooksMem.length; i++)
        for (uint8 i = 0; i < 16; i++) {
            if ((hooks_flags & (1 << (15 - i))) != 0) {
                selectedHooks[index] = hooksMem[i];
                index++;
            }
        }

        return selectedHooks;
    }

    function changeHooks(Hook[] memory updatedHooks, uint256 updatedActivatedHooks) external onlyOwner {
        _setHooks(updatedHooks, pendingHooks, updatedActivatedHooks);
        //TODO: Timer
    }

    function acceptNewHooks() external onlyOwner {
        hooks = pendingHooks;
        delete pendingHooks;
        //TODO: Timer
    }

    function rejectNewHooks() external onlyOwner {
        delete pendingHooks;
    }
    
    function _setHooks(Hook[] memory initHooks, Hook[] storage shooks, uint256 initActivatedHooks) private {
         if (initHooks.length > MAX_HOOKS_COUNT) {
            revert MaxHooksCountExceeded();
        }

        activatedHooks = initActivatedHooks;

        //TODO: validate flags
        for (uint256 i = 0; i < initHooks.length; ++i) {
            if (initHooks[i].hookAddress == address(0)) {
                revert ZeroAddress();
            }

            shooks.push(initHooks[i]);
        }
    }

    function _callOptionalReturn(address callTo, bytes memory data) private {
        console.log("_callOptionalReturn");
        assembly ("memory-safe") {
            let success := call(gas(), callTo, 0, add(data, 0x20), mload(data), 0, 0x20)

            // Copy the returned data.
            // returndatacopy(t, f, s) - copy s bytes from returndata at position f to mem at position t
            // returndatasize() - size of the last returndata
            returndatacopy(0, 0, returndatasize())

            switch success
            // delegatecall returns 0 on error.
            case 0 {
                // revert(p, s) - end execution, revert state changes, return data mem[p…(p+s))
                revert(0, returndatasize())
            }
            default {
                // return(p, s) - end execution, return data mem[p…(p+s))
                return(0, returndatasize())
            }
        }
    }

}
