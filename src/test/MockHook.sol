// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {BaseHook, Hooks, IHooks, IPoolManager, PoolKey, BalanceDelta, BeforeSwapDelta} from "../base/BaseHook.sol";
import {MultihookLib, PackedHook} from "../MultihookLib.sol";


import {BalanceDeltaLibrary, toBalanceDelta} from "v4-core/types/BalanceDelta.sol";

import "forge-std/console.sol";

contract MockHook {
    using BalanceDeltaLibrary for BalanceDelta;

    BalanceDelta public deltaAfterAddLiquidity;
    BalanceDelta public deltaAfterRemoveLiquidity;

    BeforeSwapDelta public beforeSwapDelta;
    uint24 public beforeSwapFee;

    int128 public afterSwapDeltaUnspecified;

    //Args
    IPoolManager.ModifyLiquidityParams public argsParamsAfterAddLiquidity;
    BalanceDelta public argsDeltaAfterAddLiquidity;

    IPoolManager.ModifyLiquidityParams public argsParamsAfterRemoveLiquidity;
    BalanceDelta public argsDeltaAfterRemoveLiquidity;

    IPoolManager.SwapParams public argsBeforeSwapParams;

    IPoolManager.SwapParams public argsAfterSwapParams;
    BalanceDelta public argsAfterSwapDelta;

    Hooks.Permissions private permissions;
    IPoolManager public poolManager;


    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
        permissions = Hooks.Permissions({
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

    function getHookPermissions()
        public
        view
        returns (Hooks.Permissions memory)
    {
        return permissions;
    }

    function setHookPermissions(Hooks.Permissions memory _permissions)
        public
        returns (Hooks.Permissions memory)
    {
        permissions = _permissions;
    }

    function beforeInitialize(
        address /*sender*/,
        PoolKey calldata /*key*/,
        uint160 /*sqrtPriceX96*/
    ) external pure  returns (bytes4) {
        return BaseHook.beforeInitialize.selector;
    }

    function afterInitialize(
        address /*sender*/,
        PoolKey calldata /*key*/,
        uint160 /*sqrtPriceX96*/,
        int24 /*tick*/
    ) external pure  returns (bytes4) {
        return BaseHook.afterInitialize.selector;
    }

    function beforeAddLiquidity(
        address /*sender*/,
        PoolKey calldata /*key*/,
        IPoolManager.ModifyLiquidityParams calldata /*params*/,
        bytes calldata /*hookData*/
    ) external pure  returns (bytes4) {
        return BaseHook.beforeAddLiquidity.selector;
    }

    function beforeRemoveLiquidity(
        address /*sender*/,
        PoolKey calldata /*key*/,
        IPoolManager.ModifyLiquidityParams calldata /*params*/,
        bytes calldata /*hookData*/
    ) external pure  returns (bytes4) {
        return BaseHook.beforeRemoveLiquidity.selector;
    }

    function afterAddLiquidity(
        address /*sender*/,
        PoolKey calldata /*key*/,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata /*hookData*/
    ) external  returns (bytes4, BalanceDelta) {
        argsParamsAfterAddLiquidity = params;
        argsDeltaAfterAddLiquidity = delta;
        return (BaseHook.afterAddLiquidity.selector, deltaAfterAddLiquidity);
    }

    function afterRemoveLiquidity(
        address /*sender*/,
        PoolKey calldata /*key*/,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata /*hookData*/
    ) external  returns (bytes4, BalanceDelta) {
        argsParamsAfterRemoveLiquidity = params;
        argsDeltaAfterRemoveLiquidity = delta;
        return (BaseHook.afterRemoveLiquidity.selector, deltaAfterRemoveLiquidity);
    }

    function beforeSwap(
        address /*sender*/,
        PoolKey calldata /*key*/,
        IPoolManager.SwapParams calldata params,
        bytes calldata /*hookData*/
    ) external  returns (bytes4, BeforeSwapDelta, uint24) {
        argsBeforeSwapParams = params;
        return (BaseHook.beforeSwap.selector, beforeSwapDelta, beforeSwapFee);
    }

    function afterSwap(
        address /*sender*/,
        PoolKey calldata /*key*/,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta, 
        bytes calldata /*hookData*/
    ) external  returns (bytes4, int128) {
        argsAfterSwapParams = params;
        argsAfterSwapDelta = delta;
        return (BaseHook.afterSwap.selector, afterSwapDeltaUnspecified);
    }

    function beforeDonate(
        address /*sender*/,
        PoolKey calldata /*key*/,
        uint256 /*amount0*/,
        uint256 /*amount1*/,
        bytes calldata /*hookData*/
    ) external  pure returns (bytes4) {
        return BaseHook.beforeDonate.selector;
    }

    function afterDonate( 
        address /*sender*/,
        PoolKey calldata /*key*/,
        uint256 /*amount0*/,
        uint256 /*amount1*/,
        bytes calldata /*hookData*/
    ) external  pure returns (bytes4) {
        return BaseHook.afterDonate.selector;
    }

    function setDeltaAfterAddLiquidity(BalanceDelta _deltaAfterAddLiquidity) external {
        deltaAfterAddLiquidity = _deltaAfterAddLiquidity;
    }

    function setDeltaAfterRemoveLiquidity(BalanceDelta _deltaAfterRemoveLiquidity) external {
        deltaAfterRemoveLiquidity = _deltaAfterRemoveLiquidity;
    }

    function setBeforeSwapDelta(BeforeSwapDelta _beforeSwapDelta) external {
        beforeSwapDelta = _beforeSwapDelta;
    }

    function setBeforeSwapFee(uint24 _beforeSwapFee) external {
        beforeSwapFee = _beforeSwapFee;
    }

    function setAfterSwapDeltaUnspecified(int128 _afterSwapDeltaUnspecified) external {
        afterSwapDeltaUnspecified = _afterSwapDeltaUnspecified;
    }
}
