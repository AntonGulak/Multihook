// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";

import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {BeforeSwapDelta, toBeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {BaseHook, BalanceDelta} from "v4-periphery/src/base/hooks/BaseHook.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

struct Hook {
    IHooks hook;
    uint16 flags;
}

//TODO: executeBeforeInitialize .. change to 1 method with _callOptionalReturn
library HookLib {
    function executeBeforeInitialize(
        Hook[] memory hooks,
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        bytes calldata hookData
    ) internal {
        for (uint256 i = 0; i < hooks.length; ++i) {
            hooks[i].hook.beforeInitialize(sender, key, sqrtPriceX96, hookData);
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
            hooks[i].hook.afterInitialize(sender, key, sqrtPriceX96, tick, hookData);
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
            hooks[i].hook.beforeAddLiquidity(sender, key, params, hookData);
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
            hooks[i].hook.beforeRemoveLiquidity(sender, key, params, hookData);
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
            (, delta) = hooks[i].hook.afterAddLiquidity(sender, key, params, delta, hookData);
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
            (, delta) = hooks[i].hook.afterRemoveLiquidity(sender, key, params, delta, hookData);
        }

        return delta;
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
            hooks[i].hook.beforeDonate(sender, key, amount0, amount1, hookData); 
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
            hooks[i].hook.afterDonate(sender, key, amount0, amount1, hookData); 
        }
    }
}
