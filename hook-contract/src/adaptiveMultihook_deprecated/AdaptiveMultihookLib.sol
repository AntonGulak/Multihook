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

struct Hook {
    IHooks hook;
    uint96 hookQueue;
}


library AdaptiveMultihookLib {
    using SafeCast for *;
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;
    using ParseBytes for bytes;
    using CustomRevert for bytes4;
    using AdaptiveMultihookLib for IHooks;

    bytes32 constant public ACTIVE_POOL_SLOT = 0x00;

    uint24 public constant HOOKS_COUNT_MASK = 0xF0000;
    uint24 public constant HOOKS_BIT_MASK = 0x0FFFF;

    uint8 public constant HOOKS_COUNT_MASK_SIZE = 4;
    uint8 public constant HOOKS_BIT_MASK_SIZE = 16;
    uint8 public constant MAX_HOOKS_COUNT = HOOKS_BIT_MASK_SIZE;

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

    /// @notice Hook did not return its selector
    error InvalidHookResponse();

    /// @notice thrown when a hook call fails
    /// @param revertReason bubbled up revert reason
    error Wrap__FailedHookCall(address hook, bytes revertReason);


    function beforeInitialize(
        Hook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        bytes calldata hookData
    ) internal {
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, BEFORE_INITIALIZE_BIT_SHIFT);
        for (uint8 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hook);
            selectedHooks[i].hook.callHook(abi.encodeCall(IHooks.beforeInitialize, (sender, key, sqrtPriceX96, hookData)));
        }
        tclearActivePool();
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
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, AFTER_INITIALIZE_BIT_SHIFT);
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hook);
            selectedHooks[i].hook.callHook(abi.encodeCall(IHooks.afterInitialize, (sender, key, sqrtPriceX96, tick, hookData)));
        }
        tclearActivePool();
    }

    function beforeAddLiquidity(
        Hook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) internal {
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, BEFORE_ADD_LIQUIDITY_BIT_SHIFT);
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hook);
            selectedHooks[i].hook.callHook(abi.encodeCall(IHooks.beforeAddLiquidity, (sender, key, params, hookData)));
        }
        tclearActivePool();
    }

    function beforeRemoveLiquidity(
        Hook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) internal {
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, BEFORE_REMOVE_LIQUIDITY_BIT_SHIFT);
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hook);
            selectedHooks[i].hook.callHook(abi.encodeCall(IHooks.beforeRemoveLiquidity, (sender, key, params, hookData)));
        }
        tclearActivePool();
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
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, AFTER_ADD_LIQUIDITY_BIT_SHIFT);

        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hook);
            BalanceDelta hookDelta = BalanceDelta.wrap(
                selectedHooks[i].hook.callHookWithReturnDelta(
                    abi.encodeCall(IHooks.afterAddLiquidity, (sender, key, params, delta, hookData)),
                    selectedHooks[i].hook.hasPermission(Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG)
                )
            );
            delta = delta + hookDelta;
            hookDeltaSumm = hookDeltaSumm + hookDelta;
        }
        tclearActivePool();
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
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, AFTER_REMOVE_LIQUIDITY_BIT_SHIFT);
        
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hook);
            BalanceDelta hookDelta = BalanceDelta.wrap(
                selectedHooks[i].hook.callHookWithReturnDelta(
                    abi.encodeCall(IHooks.afterRemoveLiquidity, (sender, key, params, delta, hookData)),
                    selectedHooks[i].hook.hasPermission(Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG)
                )
            );
            delta = delta + hookDelta;
            hookDeltaSumm = hookDeltaSumm + hookDelta;
        }
        tclearActivePool();
    }

    function beforeSwap(
        Hook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams memory params,
        bytes calldata hookData
    ) internal returns(BeforeSwapDelta delta, uint24 fee) {
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, BEFORE_SWAP_BIT_SHIFT);
        
        int256 deltaSpecifiedInit = params.amountSpecified;
        int128 deltaUnspecifiedSumm;
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hook);
            (, delta, fee) = selectedHooks[i].hook.beforeSwap(sender, key, params, hookData);
            params.amountSpecified += delta.getSpecifiedDelta();
            deltaUnspecifiedSumm += delta.getUnspecifiedDelta();
        }
        tclearActivePool();
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
    ) internal returns(int128 deltaUnspecifiedSumm) {
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, AFTER_SWAP_BIT_SHIFT);
        (int128 poolDeltaSpecified, int128 poolDeltaUnspecified) = getSpecifiedAndUnspecifiedCurrencies(delta, params.zeroForOne);
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hook);
            (bytes4 selector, int128 deltaUnspecified) = selectedHooks[i].hook.afterSwap(sender, key, params, delta, hookData);
            deltaUnspecifiedSumm += deltaUnspecified;
            poolDeltaUnspecified += deltaUnspecified;
            delta = packBalanceDelta(poolDeltaSpecified, poolDeltaUnspecified, params.zeroForOne); //TODO: last
        }
        tclearActivePool();
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
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, BEFORE_DONATE_BIT_SHIFT);
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hook);
            selectedHooks[i].hook.callHook(abi.encodeCall(IHooks.beforeDonate, (sender, key, amount0, amount1, hookData)));
        }
        tclearActivePool();
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
        Hook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, AFTER_DONATE_BIT_SHIFT);
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            tstoreActivePool(selectedHooks[i].hook);
            selectedHooks[i].hook.callHook(abi.encodeCall(IHooks.afterDonate, (sender, key, amount0, amount1, hookData)));
        }
        tclearActivePool();
    }

    function getActivatedHooks(Hook[] memory hooks, uint256 _activatedHooks, uint8 bitShift) internal pure returns (Hook[] memory) {
        uint24 hook_info = uint24((_activatedHooks >> bitShift) & 0xFFFFF);
        uint24 hooks_counts = (hook_info & HOOKS_COUNT_MASK) >> HOOKS_BIT_MASK_SIZE;
        uint16 hooks_flags = uint16(hook_info & HOOKS_BIT_MASK);

        Hook[] memory selectedHooks = new Hook[](hooks_counts);

        uint256 index;
        for (uint8 i = 0; i < hooks.length; i++) {
            if ((hooks_flags & (1 << (15 - i))) != 0) {
                selectedHooks[index] = hooks[i];
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
            tstore(ACTIVE_POOL_SLOT, hook)
        }
    }

    function tclearActivePool() internal {
        assembly ("memory-safe") {
            tstore(ACTIVE_POOL_SLOT, 0x00)
        }
    }

    function tloadPool() internal view returns(address) {
        address hookAddress;
        assembly ("memory-safe") {
            hookAddress := tload(ACTIVE_POOL_SLOT)
        }

        return hookAddress;
    }

    /// @notice performs a hook call using the given calldata on the given hook that doesnt return a delta
    /// @return result The complete data returned by the hook
    function callHook(IHooks self, bytes memory data) internal returns (bytes memory result) {
        bool success;
        assembly ("memory-safe") {
            success := call(gas(), self, 0, add(data, 0x20), mload(data), 0, 0)
        }
        // Revert with FailedHookCall, containing any error message to bubble up
        if (!success) Wrap__FailedHookCall.selector.bubbleUpAndRevertWith(address(self));

        // The call was successful, fetch the returned data
        assembly ("memory-safe") {
            // allocate result byte array from the free memory pointer
            result := mload(0x40)
            // store new free memory pointer at the end of the array padded to 32 bytes
            mstore(0x40, add(result, and(add(returndatasize(), 0x3f), not(0x1f))))
            // store length in memory
            mstore(result, returndatasize())
            // copy return data to result
            returndatacopy(add(result, 0x20), 0, returndatasize())
        }

        // Length must be at least 32 to contain the selector. Check expected selector and returned selector match.
        if (result.length < 32 || result.parseSelector() != data.parseSelector()) {
            InvalidHookResponse.selector.revertWith();
        }
    }

    /// @notice performs a hook call using the given calldata on the given hook
    /// @return int256 The delta returned by the hook
    function callHookWithReturnDelta(IHooks self, bytes memory data, bool parseReturn) internal returns (int256) {
        bytes memory result = callHook(self, data);

        // If this hook wasnt meant to return something, default to 0 delta
        if (!parseReturn) return 0;

        // A length of 64 bytes is required to return a bytes4, and a 32 byte delta
        if (result.length != 64) InvalidHookResponse.selector.revertWith();
        return result.parseReturnDelta();
    }

    function hasPermission(IHooks self, uint160 flag) internal pure returns (bool) {
        return uint160(address(self)) & flag != 0;
    }
}
