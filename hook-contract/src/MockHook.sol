// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
// import {BaseHook, Hooks, IHooks, IPoolManager, PoolKey, BalanceDelta, BeforeSwapDelta} from "./base/BaseHook.sol";
// import {MultihookLib, Hook} from "./MultihookLib.sol";

// import "forge-std/console.sol";

// contract Multihook is BaseHook {
//     BalanceDelta public deltaAfterAddLiquidity;
//     BalanceDelta public deltaAfterRemoveLiquidity;
//     BeforeSwapDelta public deltaBeforeSwap;
//     uint24 public feeBeforeSwap;


//     constructor(
//         IPoolManager poolManager) BaseHook(poolManager) {
//     }

//     function getHookPermissions()
//         public
//         pure
//         override
//         returns (Hooks.Permissions memory)
//     {
//         return
//             Hooks.Permissions({
//                 beforeInitialize: true,
//                 afterInitialize: true,
//                 beforeAddLiquidity: true, 
//                 afterAddLiquidity: true,
//                 beforeRemoveLiquidity: true,
//                 afterRemoveLiquidity: true,
//                 beforeSwap: true, 
//                 afterSwap: true,
//                 beforeDonate: true,
//                 afterDonate: true,
//                 beforeSwapReturnDelta: true,
//                 afterSwapReturnDelta: true,
//                 afterAddLiquidityReturnDelta: true,
//                 afterRemoveLiquidityReturnDelta: true
//             });
//     }

//     function beforeInitialize(
//         address sender,
//         PoolKey calldata key,
//         uint160 sqrtPriceX96,
//         bytes calldata hookData
//     ) external override returns (bytes4) {
//         return BaseHook.beforeInitialize.selector;
//     }

//     function afterInitialize(
//         address sender,
//         PoolKey calldata key,
//         uint160 sqrtPriceX96,
//         int24 tick,
//         bytes calldata hookData
//     ) external override returns (bytes4) {
//         return BaseHook.afterInitialize.selector;
//     }

//     function beforeAddLiquidity(
//         address sender,
//         PoolKey calldata key,
//         IPoolManager.ModifyLiquidityParams calldata params,
//         bytes calldata hookData
//     )
//         external
//         override
//         returns (bytes4)
//     {
//         return BaseHook.beforeAddLiquidity.selector;
//     }

    
//     function beforeRemoveLiquidity(
//         address sender,
//         PoolKey calldata key,
//         IPoolManager.ModifyLiquidityParams calldata params,
//         bytes calldata hookData
//     ) external override returns (bytes4) {
//         return BaseHook.beforeRemoveLiquidity.selector;
//     }

//     function afterAddLiquidity(
//         address sender,
//         PoolKey calldata key,
//         IPoolManager.ModifyLiquidityParams calldata params,
//         BalanceDelta delta,
//         bytes calldata hookData
//     ) external override returns (bytes4, BalanceDelta) {
//         return (BaseHook.afterAddLiquidity.selector, deltaAfterAddLiquidity);
//     }

//     function afterRemoveLiquidity(
//         address sender,
//         PoolKey calldata key,
//         IPoolManager.ModifyLiquidityParams calldata params,
//         BalanceDelta delta,
//         bytes calldata hookData
//     ) external override returns (bytes4, BalanceDelta) {
//         return (BaseHook.afterRemoveLiquidity.selector, deltaAfterRemoveLiquidity);
//     }

//     function beforeSwap(
//         address sender,
//         PoolKey calldata key,
//         IPoolManager.SwapParams calldata params,
//         bytes calldata hookData
//     ) external override returns (bytes4, BeforeSwapDelta, uint24) {
//         return (BaseHook.beforeSwap.selector, deltaBeforeSwap, feeBeforeSwap);
//     }

//     function afterSwap(
//         address sender,
//         PoolKey calldata key,
//         IPoolManager.SwapParams calldata params,
//         BalanceDelta delta, 
//         bytes calldata hookData
//     ) external override returns (bytes4, int128) {
//         return (BaseHook.afterSwap.selector, deltaUnspecified);
//     }

//     function beforeDonate(
//         address sender,
//         PoolKey calldata key,
//         uint256 amount0,
//         uint256 amount1,
//         bytes calldata hookData
//     ) external override returns (bytes4) {
//         Hook[] memory hooksMem = hooks;
//         hooksMem.executeBeforeDonate(activatedHooks, sender, key, amount0, amount1, hookData);
//         return (BaseHook.beforeDonate.selector);
//     }

//     function afterDonate( 
//         address sender,
//         PoolKey calldata key,
//         uint256 amount0,
//         uint256 amount1,
//         bytes calldata hookData
//     )
//         external
//         override
//         returns (bytes4)
//     {
//         Hook[] memory hooksMem = hooks;
//         hooksMem.executeAfterDonate(activatedHooks, sender, key, amount0, amount1, hookData);
//         return (BaseHook.afterDonate.selector);
//     }

//     function unlockCallback(bytes calldata data) external onlyByPoolManager override returns (bytes memory) {
//         IUnlockCallback hook = IUnlockCallback(MultihookLib.tloadPool());
//         return hook.unlockCallback(data);
//     }

//     function changeHooks(Hook[] memory updatedHooks, uint256 updatedActivatedHooks) external onlyOwner {
//         _setHooks(updatedHooks, pendingHooks, updatedActivatedHooks);
//         pendingActivatedHooks = updatedActivatedHooks;
//         changeHooksTimer = block.timestamp;
//         emit HooksUpdated(updatedHooks, updatedActivatedHooks, block.timestamp);
//     }

//     function acceptNewHooks() external onlyOwner {
//         if (changeHooksTimer == 0) {
//             revert NoHooksPendingApproval();
//         }
//         if (block.timestamp > changeHooksTimer + timeout) {
//             revert HooksApprovalTimedOut();
//         }

//         hooks = pendingHooks;
//         activatedHooks = pendingActivatedHooks;
//         delete pendingHooks;
//         delete pendingActivatedHooks;
//         delete changeHooksTimer; 
//         emit NewHooksAccepted(hooks, block.timestamp); 
//     }


//     function rejectNewHooks() external onlyOwner {
//         if (changeHooksTimer == 0) {
//             revert NoHooksPendingApproval();
//         }

//         delete pendingHooks;
//         delete pendingActivatedHooks;
//         delete changeHooksTimer;
//         emit NewHooksRejected(block.timestamp);
//     }
    
//     function _setHooks(Hook[] memory initHooks, Hook[] storage shooks, uint256 initActivatedHooks) private {
//          if (initHooks.length > MultihookLib.MAX_HOOKS_COUNT) {
//             revert MaxHooksCountExceeded();
//         }

//         activatedHooks = initActivatedHooks;

//         //TODO: validate
//         for (uint256 i = 0; i < initHooks.length; ++i) {
//             if (initHooks[i].hookAddress == address(0)) {
//                 revert ZeroAddress();
//             }

//             shooks.push(initHooks[i]);
//         }
//     }

//     fallback() external {
//         if (msg.sender == MultihookLib.tloadPool()) {
//            _callOptionalReturn(address(poolManager), msg.data);
//         } else {
//             revert FallbackFailure();
//         }
//     }


//     function _callOptionalReturn(address callTo, bytes memory data) private {
//         console.log("_callOptionalReturn");
//         assembly ("memory-safe") {
//             let success := call(gas(), callTo, 0, add(data, 0x20), mload(data), 0, 0x20)
//             returndatacopy(0, 0, returndatasize())

//             switch success
//             case 0 {
//                 revert(0, returndatasize())
//             }
//             default {
//                 return(0, returndatasize())
//             }
//         }
//     }

// }
