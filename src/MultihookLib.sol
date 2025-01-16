// SPDX-License-Identifier: Apache-2.0
// Anton Gulak https://t.me/gulak_a
pragma solidity =0.8.26;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BalanceDeltaLibrary, toBalanceDelta, BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Hooks, LPFeeLibrary} from "v4-core/libraries/Hooks.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {BeforeSwapDelta, toBeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {CustomRevert, ParseBytes } from "v4-core/libraries/Hooks.sol";
import {BytesLib} from "./base/BytesLib.sol";

struct PackedHook {
    IHooks hook;
    uint96 hookQueue;
    uint256 hookDataDist;
}

library MultihookLib {
    using SafeCast for *;
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;
    using ParseBytes for bytes;
    using LPFeeLibrary for uint24;
    using CustomRevert for bytes4;
    using MultihookLib for IHooks;
    using BytesLib for bytes;

    bytes32 constant public ACTIVE_POOL_SLOT = 0x00;

    uint24 public constant HOOKS_COUNT_MASK = 0xF0000;
    uint24 public constant HOOKS_BIT_MASK = 0x0FFFF;

    uint8 public constant HOOKS_COUNT_MASK_SIZE = 4;
    uint8 public constant HOOKS_BIT_MASK_SIZE = 16;

    uint8 public constant MAX_HOOKS_COUNT = HOOKS_BIT_MASK_SIZE;

    //Constants for indicating which hooks are enabled
    uint8 public constant BEFORE_INITIALIZE_BIT_SHIFT = 9 * (HOOKS_COUNT_MASK_SIZE +  HOOKS_BIT_MASK_SIZE);
    uint8 public constant AFTER_INITIALIZE_BIT_SHIFT= 8 * (HOOKS_COUNT_MASK_SIZE + HOOKS_BIT_MASK_SIZE); 

    uint8 public constant BEFORE_ADD_LIQUIDITY_BIT_SHIFT = 7 * (HOOKS_COUNT_MASK_SIZE + HOOKS_BIT_MASK_SIZE); 
    uint8 public constant AFTER_ADD_LIQUIDITY_BIT_SHIFT = 6 * (HOOKS_COUNT_MASK_SIZE + HOOKS_BIT_MASK_SIZE);

    uint8 public constant BEFORE_REMOVE_LIQUIDITY_BIT_SHIFT = 5 * (HOOKS_COUNT_MASK_SIZE + HOOKS_BIT_MASK_SIZE);
    uint8 public constant AFTER_REMOVE_LIQUIDITY_BIT_SHIFT = 4 * (HOOKS_COUNT_MASK_SIZE + HOOKS_BIT_MASK_SIZE);

    uint8 public constant BEFORE_SWAP_BIT_SHIFT = 3 * (HOOKS_COUNT_MASK_SIZE + HOOKS_BIT_MASK_SIZE);
    uint8 public constant AFTER_SWAP_BIT_SHIFT = 2 * (HOOKS_COUNT_MASK_SIZE + HOOKS_BIT_MASK_SIZE); 

    uint8 public constant BEFORE_DONATE_BIT_SHIFT = 1 * (HOOKS_COUNT_MASK_SIZE + HOOKS_BIT_MASK_SIZE);
    uint8 public constant AFTER_DONATE_BIT_SHIFT = 0;

    //Constants for indicating the order in which hooks are executed
    uint8 public constant HOOK_DATA_ACTIVATED_BIT_SHIF = 10 * HOOKS_COUNT_MASK_SIZE;

    uint8 public constant BEFORE_INITIALIZE_QUEUE_BIT_SHIFT = 9 * HOOKS_COUNT_MASK_SIZE;
    uint8 public constant AFTER_INITIALIZE_QUEUE_BIT_SHIFT= 8 * HOOKS_COUNT_MASK_SIZE;

    uint8 public constant BEFORE_ADD_LIQUIDITY_QUEUE_BIT_SHIFT = 7 * HOOKS_COUNT_MASK_SIZE;
    uint8 public constant AFTER_ADD_LIQUIDITY_QUEUE_BIT_SHIFT = 6 * HOOKS_COUNT_MASK_SIZE;

    uint8 public constant BEFORE_REMOVE_LIQUIDITY_QUEUE_BIT_SHIFT = 5 * HOOKS_COUNT_MASK_SIZE;
    uint8 public constant AFTER_REMOVE_LIQUIDITY_QUEUE_BIT_SHIFT = 4 * HOOKS_COUNT_MASK_SIZE;

    uint8 public constant BEFORE_SWAP_QUEUE_BIT_SHIFT = 3 * HOOKS_COUNT_MASK_SIZE;
    uint8 public constant AFTER_SWAP_QUEUE_BIT_SHIFT = 2 * HOOKS_COUNT_MASK_SIZE;

    uint8 public constant BEFORE_DONATE_QUEUE_BIT_SHIFT = 1 * HOOKS_COUNT_MASK_SIZE;
    uint8 public constant AFTER_DONATE_QUEUE_BIT_SHIFT = 0;
    
    uint24 public constant HOOK_DATA_INFO_MASK = 0xFFFFFF;
    uint8 public constant HOOK_DATA_POSITION_SIZE = 12;
    uint8 public constant HOOK_DATA_LENGTH_SIZE = 12;

    //Constants to indicate from which position and what length of hook data to extract
    uint8 public constant BEFORE_INITIALIZE_DATA_BIT_SHIFT = 9 * (HOOK_DATA_POSITION_SIZE + HOOK_DATA_LENGTH_SIZE);
    uint8 public constant AFTER_INITIALIZE_DATA_BIT_SHIFT= 8 * (HOOK_DATA_POSITION_SIZE + HOOK_DATA_LENGTH_SIZE);

    uint8 public constant BEFORE_ADD_LIQUIDITY_DATA_BIT_SHIFT = 7 * (HOOK_DATA_POSITION_SIZE + HOOK_DATA_LENGTH_SIZE);
    uint8 public constant AFTER_ADD_LIQUIDITY_DATA_BIT_SHIFT = 6 * (HOOK_DATA_POSITION_SIZE + HOOK_DATA_LENGTH_SIZE);

    uint8 public constant BEFORE_REMOVE_LIQUIDITY_DATA_BIT_SHIFT = 5 * (HOOK_DATA_POSITION_SIZE + HOOK_DATA_LENGTH_SIZE);
    uint8 public constant AFTER_REMOVE_LIQUIDITY_DATA_BIT_SHIFT = 4 * (HOOK_DATA_POSITION_SIZE + HOOK_DATA_LENGTH_SIZE);

    uint8 public constant BEFORE_SWAP_DATA_BIT_SHIFT = 3 * (HOOK_DATA_POSITION_SIZE + HOOK_DATA_LENGTH_SIZE);
    uint8 public constant AFTER_SWAP_DATA_BIT_SHIFT = 2 * (HOOK_DATA_POSITION_SIZE + HOOK_DATA_LENGTH_SIZE);

    uint8 public constant BEFORE_DONATE_DATA_BIT_SHIFT = 1 * (HOOK_DATA_POSITION_SIZE + HOOK_DATA_LENGTH_SIZE);
    uint8 public constant AFTER_DONATE_DATA_BIT_SHIFT = 0;

    error InvalidHookResponse();
    error Wrap__FailedHookCall(address hook, bytes revertReason);

    function beforeInitialize(
        PackedHook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96
    ) internal {
        PackedHook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, BEFORE_INITIALIZE_BIT_SHIFT, BEFORE_INITIALIZE_QUEUE_BIT_SHIFT);
        for (uint8 i = 0; i < selectedHooks.length; ++i) {
            selectedHooks[i].hook.callHook(abi.encodeCall(IHooks.beforeInitialize, (sender, key, sqrtPriceX96)));
        }
    }

    function afterInitialize(
        PackedHook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 tick
    ) internal {
        PackedHook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, AFTER_INITIALIZE_BIT_SHIFT, AFTER_INITIALIZE_QUEUE_BIT_SHIFT);
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            selectedHooks[i].hook.callHook(abi.encodeCall(IHooks.afterInitialize, (sender, key, sqrtPriceX96, tick)));
        }
    }

    function beforeAddLiquidity(
        PackedHook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) internal {
        PackedHook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, BEFORE_ADD_LIQUIDITY_BIT_SHIFT, BEFORE_ADD_LIQUIDITY_QUEUE_BIT_SHIFT);
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            bytes memory extractedData = extractData(hookData, selectedHooks[i].hookDataDist, BEFORE_ADD_LIQUIDITY_DATA_BIT_SHIFT);
            selectedHooks[i].hook.callHook(abi.encodeCall(IHooks.beforeAddLiquidity, (sender, key, params, extractedData)));
        }
    }

    function beforeRemoveLiquidity(
        PackedHook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) internal {
        PackedHook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, BEFORE_REMOVE_LIQUIDITY_BIT_SHIFT, BEFORE_REMOVE_LIQUIDITY_QUEUE_BIT_SHIFT);
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            bytes memory extractedData = extractData(hookData, selectedHooks[i].hookDataDist, BEFORE_REMOVE_LIQUIDITY_DATA_BIT_SHIFT);
            selectedHooks[i].hook.callHook(abi.encodeCall(IHooks.beforeRemoveLiquidity, (sender, key, params, extractedData)));
        }
    }

    function afterAddLiquidity(
        PackedHook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) internal returns(BalanceDelta hookDeltaSumm) {
        PackedHook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, AFTER_ADD_LIQUIDITY_BIT_SHIFT, AFTER_ADD_LIQUIDITY_QUEUE_BIT_SHIFT);

        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            bytes memory extractedData = extractData(hookData, selectedHooks[i].hookDataDist, AFTER_ADD_LIQUIDITY_DATA_BIT_SHIFT);
            BalanceDelta hookDelta = BalanceDelta.wrap(
                selectedHooks[i].hook.callHookWithReturnDelta(
                    abi.encodeCall(IHooks.afterAddLiquidity, (sender, key, params, delta, feesAccrued, extractedData)),
                    selectedHooks[i].hook.hasPermission(Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG)
                )
            );
            
            hookDeltaSumm = hookDeltaSumm + hookDelta;
        }
    }

    function afterRemoveLiquidity(
        PackedHook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) internal returns(BalanceDelta hookDeltaSumm) {
        PackedHook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, AFTER_REMOVE_LIQUIDITY_BIT_SHIFT, AFTER_REMOVE_LIQUIDITY_QUEUE_BIT_SHIFT);
        
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            bytes memory extractedData = extractData(hookData, selectedHooks[i].hookDataDist, AFTER_REMOVE_LIQUIDITY_DATA_BIT_SHIFT);
            BalanceDelta hookDelta = BalanceDelta.wrap(
                selectedHooks[i].hook.callHookWithReturnDelta(
                    abi.encodeCall(IHooks.afterRemoveLiquidity, (sender, key, params, delta, feesAccrued, extractedData)),
                    selectedHooks[i].hook.hasPermission(Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG)
                )
            );
            hookDeltaSumm = hookDeltaSumm + hookDelta;
        }
    }

    function beforeSwap(
        PackedHook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams memory params,
        bytes calldata hookData
    ) internal returns(BeforeSwapDelta hookDeltaSumm, uint24 lpFeeOverride) {
        PackedHook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, BEFORE_SWAP_BIT_SHIFT, BEFORE_SWAP_QUEUE_BIT_SHIFT);

        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            bytes memory extractedData = extractData(hookData, selectedHooks[i].hookDataDist, BEFORE_SWAP_DATA_BIT_SHIFT);
            bytes memory result = callHook(selectedHooks[i].hook, abi.encodeCall(IHooks.beforeSwap, (sender, key, params, extractedData)));
            if (result.length != 96) InvalidHookResponse.selector.revertWith();
            if (key.fee.isDynamicFee()) lpFeeOverride = result.parseFee();
            if (selectedHooks[i].hook.hasPermission(Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG)) {
                hookDeltaSumm = add(hookDeltaSumm, BeforeSwapDelta.wrap(result.parseReturnDelta()));
            }
        }
    }

    function afterSwap(
        PackedHook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta, 
        bytes calldata hookData
    ) internal returns(int128 deltaUnspecifiedSumm) {
        PackedHook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, AFTER_SWAP_BIT_SHIFT, AFTER_SWAP_QUEUE_BIT_SHIFT);
    
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            bytes memory extractedData = extractData(hookData, selectedHooks[i].hookDataDist, AFTER_SWAP_DATA_BIT_SHIFT);
            deltaUnspecifiedSumm += selectedHooks[i].hook.callHookWithReturnDelta(
                abi.encodeCall(IHooks.afterSwap, (sender, key, params, delta, extractedData)),
                selectedHooks[i].hook.hasPermission(Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG)
            ).toInt128();
        }
    }

    function beforeDonate(
        PackedHook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) internal {
        PackedHook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, BEFORE_DONATE_BIT_SHIFT, BEFORE_DONATE_QUEUE_BIT_SHIFT);
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            bytes memory extractedData = extractData(hookData, selectedHooks[i].hookDataDist, BEFORE_DONATE_DATA_BIT_SHIFT);
            selectedHooks[i].hook.callHook(abi.encodeCall(IHooks.beforeDonate, (sender, key, amount0, amount1, extractedData)));
        }
    }

    function afterDonate(
        PackedHook[] memory hooks,
        uint256 activatedHooks,
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) internal {
        PackedHook[] memory selectedHooks = getActivatedHooks(hooks, activatedHooks, AFTER_DONATE_BIT_SHIFT, AFTER_DONATE_QUEUE_BIT_SHIFT);
        for (uint256 i = 0; i < selectedHooks.length; ++i) {
            bytes memory extractedData = extractData(hookData, selectedHooks[i].hookDataDist, AFTER_DONATE_DATA_BIT_SHIFT);
            selectedHooks[i].hook.callHook(abi.encodeCall(IHooks.afterDonate, (sender, key, amount0, amount1, extractedData)));
        }
    }

    function getActivatedHooks(
        PackedHook[] memory hooks,
        uint256 _activatedHooks,
        uint8 bitShift,
        uint8 queueBitShift
    ) internal pure returns (PackedHook[] memory) {
        uint24 hook_info = uint24((_activatedHooks >> bitShift) & 0xFFFFF);
        uint24 hooks_counts = (hook_info & HOOKS_COUNT_MASK) >> HOOKS_BIT_MASK_SIZE;
        uint16 hooks_flags = uint16(hook_info & HOOKS_BIT_MASK);

        PackedHook[] memory selectedHooks = new PackedHook[](hooks_counts);

        for (uint8 i = 0; i < hooks.length; i++) {
            // 15 = (HOOKS_BIT_MASK_SIZE - 1)
            if ((hooks_flags & (1 << (15 - i))) != 0) {
                selectedHooks[getHookQueuePosition(hooks[i], queueBitShift)] = hooks[i];
            }
        }

        return selectedHooks;
    }

    function getHookQueuePosition(PackedHook memory hook, uint8 queueBitShift) internal pure returns (uint8) {
        return uint8((hook.hookQueue >> queueBitShift) & 0xF);
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

    function extractData(bytes memory hookData, uint256 hookDataDist, uint8 dataBitShift) internal pure returns (bytes memory result) {
        if (hookDataDist > 0) {
            uint24 hookDataInfo = uint24((hookDataDist >> dataBitShift) & HOOK_DATA_INFO_MASK);
            if (hookDataInfo > 0) {
                uint24 dataLength = hookDataInfo & 0xFFF;
                uint24 dataPosition = (hookDataInfo >> HOOK_DATA_LENGTH_SIZE) & 0xFFF;
                result = hookData.slice(dataPosition, dataLength);
            }
        }
    }

    function callHook(IHooks self, bytes memory data) internal returns (bytes memory result) {
        tstoreActivePool(self);

        bool success;
        assembly ("memory-safe") {
            success := call(gas(), self, 0, add(data, 0x20), mload(data), 0, 0)
        }
        if (!success) CustomRevert.bubbleUpAndRevertWith(address(self), bytes4(0), Wrap__FailedHookCall.selector);
        
        assembly ("memory-safe") {
            result := mload(0x40)
            mstore(0x40, add(result, and(add(returndatasize(), 0x3f), not(0x1f))))
            mstore(result, returndatasize())
            returndatacopy(add(result, 0x20), 0, returndatasize())
        }

        if (result.length < 32 || result.parseSelector() != data.parseSelector()) {
            InvalidHookResponse.selector.revertWith();
        }

        tclearActivePool();
    }

    function callHookWithReturnDelta(IHooks self, bytes memory data, bool parseReturn) internal returns (int256) {
        bytes memory result = callHook(self, data);
        if (!parseReturn) return 0;
        if (result.length != 64) InvalidHookResponse.selector.revertWith();
        return result.parseReturnDelta();
    }

    function add(BeforeSwapDelta a, BeforeSwapDelta b) internal pure returns (BeforeSwapDelta) {
        int256 res0;
        int256 res1;
        assembly ("memory-safe") {
            let a0 := sar(128, a)
            let a1 := signextend(15, a)
            let b0 := sar(128, b)
            let b1 := signextend(15, b)
            res0 := add(a0, b0)
            res1 := add(a1, b1)
        }
        return toBeforeSwapDelta(res0.toInt128(), res1.toInt128());
    }

    function hasPermission(IHooks self, uint160 flag) internal pure returns (bool) {
        return uint160(address(self)) & flag != 0;
    }
}
