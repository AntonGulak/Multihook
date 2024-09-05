// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";

import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {BaseHook, BalanceDelta} from "v4-periphery/src/base/hooks/BaseHook.sol";

contract CSMM is BaseHook {
    using CurrencySettler for Currency;
    
    constructor(IPoolManager poolManager) BaseHook(poolManager) {}

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

    function afterInitialize(
        address msgSender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 tick,
        bytes calldata hookData
    ) external override returns (bytes4) {
        return BaseHook.afterInitialize.selector;
    }

    function beforeAddLiquidity(
        address msgSender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    )
        external
        override
        returns (bytes4)
    {
        return BaseHook.beforeAddLiquidity.selector;
    }

    
    function beforeRemoveLiquidity(
        address msgSender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
          return BaseHook.beforeRemoveLiquidity.selector;
    }

    function afterAddLiquidity(
        address msgSender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        return (BaseHook.afterAddLiquidity.selector, delta);
    }

    function afterRemoveLiquidity(
        address msgSender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        return (BaseHook.afterRemoveLiquidity.selector, delta);
    }

    //  function beforeSwap(
    //     address msgSender,
    //     PoolKey calldata key,
    //     IPoolManager.SwapParams calldata params,
    //     bytes calldata hookData
    // ) external override returns (bytes4, BeforeSwapDelta, uint24) {
    //     uint24 fee;
    //     return (BaseHook.beforeSwap.selector, BalanceDeltaLibrary.ZERO_DELTA, fee);
    // }

    function afterSwap(
        address msgSender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta, 
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        //hookDeltaUnspecified -->Delta
        int128 hookDeltaUnspecified;

        return (BaseHook.afterSwap.selector, hookDeltaUnspecified);
    }

    // function beforeDonate(
    //     address msgSender,
    //     PoolKey calldata key,
    //     uint256 amount0,
    //     uint256 amount1,
    //     bytes calldata hookData
    // ) external override returns (bytes4) {
    //     return  (BaseHook.beforeDonate.selector);
    // }

    // function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
    //     external
    //     virtual
    //     returns (bytes4)
    // {
    //     revert HookNotImplemented();
    // }

    function _unlockCallback(
        bytes calldata data
    ) internal override returns (bytes memory) {
        return "";
    }
}
