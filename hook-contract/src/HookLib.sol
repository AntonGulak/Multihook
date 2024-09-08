// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BalanceDeltaLibrary, toBalanceDelta} from "v4-core/types/BalanceDelta.sol";

import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {BeforeSwapDelta, toBeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {BaseHook, BalanceDelta} from "v4-periphery/src/base/hooks/BaseHook.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

import "forge-std/console.sol";


struct Hook {
    address hookAddress;
    uint96 hookQueue;
}

struct HookPacked {
    address hookAddress;
    uint8 hookId;
}

//TODO: executeBeforeInitialize .. change to 1 method with _callOptionalReturn
library HookLib {
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;
    bytes32 constant public ACTIVE_POOL_SLOT = 0x00;

    function executeBeforeInitialize(
        Hook[] memory hooks,
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        bytes calldata hookData
    ) internal {
        for (uint8 i = 0; i < hooks.length; ++i) {
            tstoreActivePool(hooks[i].hookAddress);
            IHooks(hooks[i].hookAddress).beforeInitialize(sender, key, sqrtPriceX96, hookData);
        }
    }

    function executeAfterInitialize(
        Hook[] memory hooks,
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 tick,
        bytes calldata hookData
    ) internal {
        for (uint256 i = 0; i < hooks.length; ++i) {
            tstoreActivePool(hooks[i].hookAddress);
            IHooks(hooks[i].hookAddress).afterInitialize(sender, key, sqrtPriceX96, tick, hookData);
        }
    }

    function executeBeforeAddLiquidity(
        Hook[] memory hooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) internal {
        for (uint256 i = 0; i < hooks.length; ++i) {
            tstoreActivePool(hooks[i].hookAddress);
            IHooks(hooks[i].hookAddress).beforeAddLiquidity(sender, key, params, hookData);
        }
    }

    function executeBeforeRemoveLiquidity(
        Hook[] memory hooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) internal {
        for (uint256 i = 0; i < hooks.length; ++i) {
            tstoreActivePool(hooks[i].hookAddress);
            IHooks(hooks[i].hookAddress).beforeRemoveLiquidity(sender, key, params, hookData);
        }
    }

    function executeAfterAddLiquidity(
        Hook[] memory hooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal returns(BalanceDelta) {
        for (uint256 i = 0; i < hooks.length; ++i) {
            tstoreActivePool(hooks[i].hookAddress);
            (, delta) = IHooks(hooks[i].hookAddress).afterAddLiquidity(sender, key, params, delta, hookData);
        }

        return delta;
    }

    function executeAfterRemoveLiquidity(
        Hook[] memory hooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal returns(BalanceDelta) {
        for (uint256 i = 0; i < hooks.length; ++i) {
            tstoreActivePool(hooks[i].hookAddress);
            (, delta) = IHooks(hooks[i].hookAddress).afterRemoveLiquidity(sender, key, params, delta, hookData);
        }

        return delta;
    }

    function executeBeforeSwap(
        Hook[] memory hooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) internal returns(BeforeSwapDelta, uint24) {
        int128 deltaSpecified;
        int128 deltaUnspecified;
        uint24 fee;
        for (uint256 i = 0; i < hooks.length; ++i) {
            tstoreActivePool(hooks[i].hookAddress);
            console.log("executeBeforeSwap 1");
            (bytes4 selector, BeforeSwapDelta delta, uint24 lpFee) = IHooks(hooks[i].hookAddress).beforeSwap(sender, key, params, hookData);
            console.log("executeBeforeSwap 2");
            deltaSpecified += delta.getSpecifiedDelta();
            deltaUnspecified += delta.getUnspecifiedDelta();
            fee = lpFee; //TODO
        }

        //TODO: fees
        return (toBeforeSwapDelta(deltaSpecified, deltaUnspecified), fee);
    }

    function executeAfterSwap(
        Hook[] memory hooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta, 
        bytes calldata hookData
    ) internal returns(int128) {
        (int128 deltaSpecified, int128 deltaUnspecified) = getSpecifiedAndUnspecifiedCurrencies(delta, params.zeroForOne);
        
        for (uint256 i = 0; i < hooks.length; ++i) {
            tstoreActivePool(hooks[i].hookAddress);
            bytes4 selector;
            (selector, deltaUnspecified) = IHooks(hooks[i].hookAddress).afterSwap(sender, key, params, delta, hookData);
            deltaUnspecified = deltaUnspecified;
            delta = packBalanceDelta(deltaSpecified, deltaUnspecified, params.zeroForOne); //TODO: last
        }

        return deltaUnspecified;
    }

    function executeBeforeDonate(
        Hook[] memory hooks,
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) internal {
        for (uint256 i = 0; i < hooks.length; ++i) {
            tstoreActivePool(hooks[i].hookAddress);
            IHooks(hooks[i].hookAddress).beforeDonate(sender, key, amount0, amount1, hookData); 
        }
    }

    function executeAfterDonate(
        Hook[] memory hooks,
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) internal {
        for (uint256 i = 0; i < hooks.length; ++i) {
            tstoreActivePool(hooks[i].hookAddress);
            IHooks(hooks[i].hookAddress).afterDonate(sender, key, amount0, amount1, hookData); 
        }
    }

    function getSpecifiedAndUnspecifiedCurrencies(
        BalanceDelta balanceDelta,
        bool zeroForOne
    ) internal pure returns (int128 specifiedCurrencyAmount, int128 unspecifiedCurrencyAmount) {
        int128 amount0 = balanceDelta.amount0();
        int128 amount1 = balanceDelta.amount1();

        if (zeroForOne) {
            // Своп из token0 в token1
            if (amount0 < 0) {
                // Пользователь указывает количество token0, следовательно, это specifiedCurrency
                specifiedCurrencyAmount = -amount0;
                unspecifiedCurrencyAmount = amount1;
            } else {
                // Пользователь указывает количество token1, следовательно, это specifiedCurrency
                specifiedCurrencyAmount = -amount1;
                unspecifiedCurrencyAmount = amount0;
            }
        } else {
            // Своп из token1 в token0
            if (amount1 < 0) {
                // Пользователь указывает количество token1, следовательно, это specifiedCurrency
                specifiedCurrencyAmount = -amount1;
                unspecifiedCurrencyAmount = amount0;
            } else {
                // Пользователь указывает количество token0, следовательно, это specifiedCurrency
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
            // specifiedCurrency это token0, unspecifiedCurrency это token1
            amount0 = deltaSpecified;
            amount1 = deltaUnspecified;
        } else {
            // specifiedCurrency это token1, unspecifiedCurrency это token0
            amount0 = deltaUnspecified;
            amount1 = deltaSpecified;
        }

        // Упаковка значений в BalanceDelta
        balanceDelta = toBalanceDelta(amount0, amount1);
    }

    function tstoreActivePool(address hookAddress) internal {
        // HookPacked memory hookPacked = HookPacked(hookInfo.hookAddress, poolId);
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
