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

import {HookLib, Hook} from "./HookLib.sol";

//hooks sload to tload !!! TODO:
//fallback ==> poolmanager proxy

contract Multihook is BaseHook {
    using CurrencySettler for Currency;
    using HookLib for Hook[];
    
    Hook[] public hooks;
    mapping(IHooks => bool) public isHook;
    
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

    function beforeInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        bytes calldata hookData
    ) external override returns (bytes4) {
        Hook[] memory hooksMem = hooks;
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
        Hook[] memory hooksMem = hooks;
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
        Hook[] memory hooksMem = hooks;
        hooksMem.executeBeforeAddLiquidity(sender, key, params, hookData);
        return BaseHook.beforeAddLiquidity.selector;
    }

    
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        Hook[] memory hooksMem = hooks;
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
        Hook[] memory hooksMem = hooks;
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
        Hook[] memory hooksMem = hooks;
        delta = hooksMem.executeAfterAddLiquidity(sender, key, params, delta, hookData);
        return (BaseHook.afterRemoveLiquidity.selector, delta);
    }

     function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
        uint24 fee;
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, fee);
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta, 
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        //hookDeltaUnspecified -->Delta
        int128 hookDeltaUnspecified;

        return (BaseHook.afterSwap.selector, hookDeltaUnspecified);
    }

    function beforeDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external override returns (bytes4) {
        Hook[] memory hooksMem = hooks;
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
        Hook[] memory hooksMem = hooks;
        hooksMem.executeAfterDonate(sender, key, amount0, amount1, hookData);
        return (BaseHook.afterDonate.selector);
    }

    //rewrite SafeCallback
    function unlockCallback(bytes calldata data) external onlyByPoolManager override returns (bytes memory) {
        //прочитать из tsload какой хук ушёл в анлок коллбэк и вызвать его unlockCallback
        return "";
    }

    fallback() external {
        //прочитать из tsload какой хук был вызван и работать только лишь с ним
        if (isHook[IHooks(msg.sender)]) {
           _callOptionalReturn(address(poolManager), msg.data);
        } else {
            revert("fallback"); //TODO
        }
    }

    function _callOptionalReturn(address callTo, bytes memory data) private {
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            let success := call(gas(), callTo, 0, add(data, 0x20), mload(data), 0, 0x20)
            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        //TODO:
        // if (returnSize == 0 ? address(callTo).code.length == 0 : returnValue != 1) {
        //     revert
        // }
    }
}
