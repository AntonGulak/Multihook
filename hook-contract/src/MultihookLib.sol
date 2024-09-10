// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BalanceDeltaLibrary, toBalanceDelta} from "v4-core/types/BalanceDelta.sol";

import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {BeforeSwapDelta, toBeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {BaseHook, BalanceDelta} from "v4-periphery/src/base/hooks/BaseHook.sol";

import {Hooks, CustomRevert, ParseBytes } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

import "forge-std/console.sol";


struct Hook {
    IHooks hook;
    uint96 hookQueue;
}

struct HookPacked {
    address hookAddress;
    uint8 hookId;
}


library MultihookLib {
    using Hooks for IHooks;

    using SafeCast for *;
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;

    bytes32 constant public ACTIVE_POOL_SLOT = 0x00;

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

    //4 bits are allocated for the number of active hooks for a given method, and a 16-bit segment is used for the active hook flags.
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

    function beforeInitialize(
        Hook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        bytes calldata hookData
    ) internal {
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, BEFORE_INITIALIZE_HOOK_FLAGS, BEFORE_INITIALIZE_BIT_SHIFT);
        for (uint8 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hook);
            IHooks(selectedHooks[i].hookAddress).beforeInitialize(sender, key, sqrtPriceX96, hookData);
        }
    }

    function afterInitialize(
        Hook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 tick,
        bytes calldata hookData
    ) internal {
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, AFTER_INITIALIZE_HOOK_FLAGS, AFTER_INITIALIZE_BIT_SHIFT);
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hookAddress);
            IHooks(selectedHooks[i].hookAddress).afterInitialize(sender, key, sqrtPriceX96, tick, hookData);
        }
    }

    function beforeAddLiquidity(
        Hook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) internal {
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, BEFORE_ADD_LIQUIDITY_HOOK_FLAGS, BEFORE_ADD_LIQUIDITY_BIT_SHIFT);
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hookAddress);
            IHooks(selectedHooks[i].hookAddress).beforeAddLiquidity(sender, key, params, hookData);
        }
    }

    function beforeRemoveLiquidity(
        Hook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) internal {
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, BEFORE_REMOVE_LIQUIDITY_HOOK_FLAGS, BEFORE_REMOVE_LIQUIDITY_BIT_SHIFT);
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hookAddress);
            IHooks(selectedHooks[i].hookAddress).beforeRemoveLiquidity(sender, key, params, hookData);
        }
    }

    function afterAddLiquidity(
        Hook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal returns(BalanceDelta hookDeltaSumm) {
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, AFTER_ADD_LIQUIDITY_HOOK_FLAGS, AFTER_ADD_LIQUIDITY_BIT_SHIFT);
        
        BalanceDelta hookDelta;
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hookAddress);
            (, hookDelta) = IHooks(selectedHooks[i].hookAddress).afterAddLiquidity(sender, key, params, delta, hookData);
            delta = delta + hookDelta;
            hookDeltaSumm = hookDeltaSumm + hookDelta;
        }
    }

    function afterRemoveLiquidity(
        Hook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal returns(BalanceDelta hookDeltaSumm) {
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, AFTER_REMOVE_LIQUIDITY_HOOK_FLAGS, AFTER_REMOVE_LIQUIDITY_BIT_SHIFT);
        
        BalanceDelta hookDelta;
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hookAddress);
            (, hookDelta) = IHooks(selectedHooks[i].hookAddress).afterRemoveLiquidity(sender, key, params, delta, hookData);
            delta = delta + hookDelta;
            hookDeltaSumm = hookDeltaSumm + hookDelta;
        }
    }

    function beforeSwap(
        Hook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams memory params,
        bytes calldata hookData
    ) internal returns(BeforeSwapDelta delta, uint24 fee) {
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, BEFORE_SWAP_HOOK_FLAGS, BEFORE_SWAP_BIT_SHIFT);
        
        int256 deltaSpecifiedInit = params.amountSpecified;
        int128 deltaUnspecifiedSumm;
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hookAddress);
            (, delta, fee) = IHooks(selectedHooks[i].hookAddress).beforeSwap(sender, key, params, hookData);
            params.amountSpecified += delta.getSpecifiedDelta();
            deltaUnspecifiedSumm += delta.getUnspecifiedDelta();
        }

        delta = toBeforeSwapDelta((params.amountSpecified - deltaSpecifiedInit).toInt128(), deltaUnspecifiedSumm);
    }

    function afterSwap(
        Hook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta, 
        bytes calldata hookData
    ) internal returns(int128) {
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, AFTER_SWAP_HOOK_FLAGS, AFTER_SWAP_BIT_SHIFT);
        (int128 poolDeltaSpecified, int128 poolDeltaUnspecified) = getSpecifiedAndUnspecifiedCurrencies(delta, params.zeroForOne);

        int128 deltaUnspecifiedSumm;
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hookAddress);
            (bytes4 selector, int128 deltaUnspecified) = IHooks(selectedHooks[i].hookAddress).afterSwap(sender, key, params, delta, hookData);
            deltaUnspecifiedSumm += deltaUnspecified;
            poolDeltaUnspecified += deltaUnspecified;
            delta = packBalanceDelta(poolDeltaSpecified, poolDeltaUnspecified, params.zeroForOne); //TODO: last
        }

        return deltaUnspecifiedSumm;
    }

    function beforeDonate(
        Hook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) internal {
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, BEFORE_DONATE_HOOK_FLAGS, BEFORE_DONATE_BIT_SHIFT);
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hookAddress);
            IHooks(selectedHooks[i].hookAddress).beforeDonate(sender, key, amount0, amount1, hookData); 
        }
    }

    function afterDonate(
        Hook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) internal {
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, AFTER_DONATE_HOOK_FLAGS, AFTER_DONATE_BIT_SHIFT);
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hookAddress);
            IHooks(selectedHooks[i].hookAddress).afterDonate(sender, key, amount0, amount1, hookData); 
        }
    }

    function getActivatedHooks(Hook[] memory hooksMem, uint256 _activatedHooks, uint256 hookFlags, uint8 bitShift) internal pure returns (Hook[] memory) {
        uint24 hook_info = uint24((_activatedHooks & hookFlags ) >> bitShift);

        uint24 hooks_counts = (hook_info & HOOKS_COUNT_MASK) >> HOOKS_BIT_MASK_SIZE;
        uint16 hooks_flags = uint16(hook_info & HOOKS_BIT_MASK);

        Hook[] memory selectedHooks = new Hook[](hooks_counts);

        uint256 index;
        for (uint8 i = 0; i < hooksMem.length; i++) {
            if ((hooks_flags & (1 << (15 - i))) != 0) {
                selectedHooks[index] = hooksMem[i];
                index++;
            }
        }

        return selectedHooks;
    }


    function getSpecifiedAndUnspecifiedCurrencies(
        BalanceDelta balanceDelta,
        bool zeroForOne
    ) internal pure returns (int128 specifiedCurrencyAmount, int128 unspecifiedCurrencyAmount) {
        int128 amount0 = balanceDelta.amount0();
        int128 amount1 = balanceDelta.amount1();

        if (zeroForOne) {
            if (amount0 < 0) {
                specifiedCurrencyAmount = -amount0;
                unspecifiedCurrencyAmount = amount1;
            } else {
                specifiedCurrencyAmount = -amount1;
                unspecifiedCurrencyAmount = amount0;
            }
        } else {
            if (amount1 < 0) {
                specifiedCurrencyAmount = -amount1;
                unspecifiedCurrencyAmount = amount0;
            } else {
                specifiedCurrencyAmount = -amount0;
                unspecifiedCurrencyAmount = amount1;
            }
        }
    }

    function packBalanceDelta(
        int128 deltaSpecified,
        int128 deltaUnspecified,
        bool zeroForOne
    ) internal pure returns (BalanceDelta balanceDelta) {
        int128 amount0;
        int128 amount1;

        if (zeroForOne) {
            amount0 = deltaSpecified;
            amount1 = deltaUnspecified;
        } else {
            amount0 = deltaUnspecified;
            amount1 = deltaSpecified;
        }

        balanceDelta = toBalanceDelta(amount0, amount1);
    }

    function tstoreActivePool(IHooks hook) internal {
        assembly ("memory-safe") {
            tstore(ACTIVE_POOL_SLOT, hookAddress)
        }
    }

    function tloadPool() internal view returns(address) {
        address hookAddress;
        assembly ("memory-safe") {
            hookAddress := tload(ACTIVE_POOL_SLOT)
        }

        return hookAddress;
    }
}
