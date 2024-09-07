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

    uint8 public constant MAX_HOOKS_COUNT = 25;

    Hook[] public hooks;
    Hook[] public pendingHooks;
    
    constructor(IPoolManager poolManager, Hook[] memory initHooks, address manager) BaseHook(poolManager) Ownable(manager) {
       _setHooks(initHooks, hooks);
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
        // Hook[] memory hooksMem = hooks;
        // hooksMem.executeAfterInitialize(sender, key, sqrtPriceX96, tick, hookData);
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
        Hook[] memory hooksMem = hooks;
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
        Hook[] memory hooksMem = hooks;
        int128 deltaUnspecified = hooksMem.executeAfterSwap(sender, key, params, delta, hookData);
        return (BaseHook.beforeSwap.selector, deltaUnspecified);
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

    function changeHooks(Hook[] memory updatedHooks) external onlyOwner {
        _setHooks(updatedHooks, pendingHooks);
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
    
    function _setHooks(Hook[] memory initHooks, Hook[] storage shooks) private {
         if (initHooks.length > MAX_HOOKS_COUNT) {
            revert MaxHooksCountExceeded();
        }

        //TODO: validate flags
        for (uint256 i = 0; i < initHooks.length; ++i) {
            if (initHooks[i].hookAddress == address(0)) {
                revert ZeroAddress();
            }

            shooks.push(initHooks[i]);
        }
    }

    function _callOptionalReturn(address callTo, bytes memory data) private {
        //TODO: FUNCTIONS WITHOUT RETURN DATA
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
