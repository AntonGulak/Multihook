// SPDX-License-Identifier: Apache-2.0
// Anton Gulak https://t.me/gulak_a
pragma solidity =0.8.26;

import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {BaseHook, IHookPermissions} from "./base/BaseHook.sol";
import {MultihookLib, CustomRevert, PackedHook, ParseBytes} from "./MultihookLib.sol";

import "forge-std/console.sol";

struct AcceptedMethod {
    address hook;
    bytes4 signature;
    bool status;
}

struct MultiHookInitParams {
    IPoolManager poolManager;
    Currency currency0;
    Currency currency1;
    PackedHook[] initHooks;
    AcceptedMethod[] acceptedMethods;
    uint256 initActivatedHooks;
    address manager;
    uint256 initTimeout;
}

contract Multihook is BaseHook, Ownable2Step {
    using ParseBytes for bytes;
    using MultihookLib for PackedHook[];
    using CurrencyLibrary for Currency;
    using CustomRevert for bytes4;

    Currency public currency0;
    Currency public currency1;

    uint256 public changeHooksTimer;
    uint256 public activatedHooks;
    PackedHook[] public hooks;

    uint256 public pendingActivatedHooks;
    AcceptedMethod[] public pendingAcceptedMethods;
    PackedHook[] public pendingHooks;

    uint256 public timeout;
    mapping(bytes32 hookAddressWithSelector => bool) public selectorIsApproved;

    error NoHooksPendingApproval();
    error HooksApprovalTimedOut();
    error HooksAlreadyPending();
    error MaxHooksCountExceeded();
    error ZeroAddress();
    error FallbackFailure();
    error IncorrectPoolId();

    event HooksUpdated(PackedHook[] updatedHooks, uint256 updatedActivatedHooks, uint256 timestamp);
    event NewHooksAccepted(PackedHook[] acceptedHooks, uint256 timestamp);
    event NewHooksRejected(uint256 timestamp);
    event HooksTimeoutExceeded(uint256 timestamp);
    
    constructor(MultiHookInitParams memory params) BaseHook(params.poolManager) Ownable(params.manager) {
       _setHooks(params.initHooks, hooks);
       _acceptMethods(params.acceptedMethods);
       activatedHooks = params.initActivatedHooks;
       timeout = params.initTimeout;
       currency0 = params.currency0;
       currency1 = params.currency1;
    }

    fallback() external {
        /*
            TODO: For greater compatibility, it is necessary to allow all active hooks to send 
            requests to the PoolManager via fallback (if these are custom methods).
            However, security considerations must be carefully thought
        */
        if (msg.sender == MultihookLib.tloadPool()) {
            if (msg.data.parseSelector() == IPoolManager.settle.selector) {
                currency0.transfer(address(poolManager), currency0.balanceOfSelf());
                currency1.transfer(address(poolManager), currency1.balanceOfSelf());
            }
           _callOptionalReturn(address(poolManager), msg.data);
        } else {
            FallbackFailure.selector.revertWith();
        }
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
        uint160 sqrtPriceX96
    ) external override returns (bytes4) {
        getHooks().beforeInitialize(activatedHooks, sender, key, sqrtPriceX96);
        return BaseHook.beforeInitialize.selector;
    }

    function afterInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 tick
    ) external override returns (bytes4) {
        getHooks().afterInitialize(activatedHooks, sender, key, sqrtPriceX96, tick);
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
        getHooks().beforeAddLiquidity(activatedHooks, sender, key, params, hookData);
        return BaseHook.beforeAddLiquidity.selector;
    }

    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        getHooks().beforeRemoveLiquidity(activatedHooks, sender, key, params, hookData);
        return BaseHook.beforeRemoveLiquidity.selector;
    }

    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        delta = getHooks().afterAddLiquidity(activatedHooks, sender, key, params, delta, feesAccrued, hookData);
        return (BaseHook.afterAddLiquidity.selector, delta);
    }

    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        delta = getHooks().afterRemoveLiquidity(activatedHooks, sender, key, params, delta, feesAccrued, hookData);
        return (BaseHook.afterRemoveLiquidity.selector, delta);
    }

     function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
        (BeforeSwapDelta delta, uint24 fee) = getHooks().beforeSwap(activatedHooks, sender, key, params, hookData);
        return (BaseHook.beforeSwap.selector, delta, fee);
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta, 
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        int128 deltaUnspecified = getHooks().afterSwap(activatedHooks, sender, key, params, delta, hookData);
        return (BaseHook.afterSwap.selector, deltaUnspecified);
    }

    function beforeDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external override returns (bytes4) {
        getHooks().beforeDonate(activatedHooks, sender, key, amount0, amount1, hookData);
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
        getHooks().afterDonate(activatedHooks, sender, key, amount0, amount1, hookData);
        return (BaseHook.afterDonate.selector);
    }

    function unlockCallback(bytes calldata data) external onlyByPoolManager override returns (bytes memory) {
        IUnlockCallback hook = IUnlockCallback(MultihookLib.tloadPool());
        return hook.unlockCallback(data);
    }

    function customCallToSubhook(uint8 poolId, bytes memory data) external {
        if (poolId >= hooks.length) IncorrectPoolId.selector.revertWith();
        address hookAddress = address(hooks[poolId].hook);

        if (selectorIsApproved[bytes32(bytes20(uint160(hookAddress))) | (bytes32(data.parseSelector()) >> 224)]) {
            MultihookLib.tstoreActivePool(IHooks(hookAddress));
            _callOptionalReturnAndClearActivePool(hookAddress, data);
        }
    }
    

    function changeHooks(
        PackedHook[] memory updatedHooks,
        AcceptedMethod[] memory updatedAcceptedMethods,
        uint256 updatedActivatedHooks
    ) external onlyOwner {
        _setHooks(updatedHooks, pendingHooks);
        pendingActivatedHooks = updatedActivatedHooks;
        changeHooksTimer = block.timestamp;
        for (uint256 i = 0; i < updatedAcceptedMethods.length; ++i) pendingAcceptedMethods.push(updatedAcceptedMethods[i]);
        emit HooksUpdated(updatedHooks, updatedActivatedHooks, block.timestamp);
    }

    function acceptNewHooks() external onlyOwner {
        if (changeHooksTimer == 0) {
            NoHooksPendingApproval.selector.revertWith();
        }
        if (block.timestamp > changeHooksTimer + timeout) {
            HooksApprovalTimedOut.selector.revertWith();
        }
        _setHooks(pendingHooks, hooks);
        _acceptMethods(pendingAcceptedMethods);
        activatedHooks = pendingActivatedHooks;
        changeHooksTimer  = 0; 

        delete pendingHooks;
        delete pendingActivatedHooks;
        emit NewHooksAccepted(hooks, block.timestamp); 
    }


    function rejectNewHooks() external onlyOwner {
        if (changeHooksTimer == 0) {
            NoHooksPendingApproval.selector.revertWith();
        }

        changeHooksTimer = 0;
        delete pendingHooks;
        delete pendingActivatedHooks;
        delete pendingActivatedHooks;
        emit NewHooksRejected(block.timestamp);
    }

    function getHooks() private view returns(PackedHook[] memory) {
        return hooks;
    }
    
    function _setHooks(
        PackedHook[] memory newHooks,
        PackedHook[] storage cellHooks
    ) private {
        if (newHooks.length > MultihookLib.MAX_HOOKS_COUNT) {
            MaxHooksCountExceeded.selector.revertWith();
        }
        for (uint256 i = 0; i < newHooks.length; ++i) {
            address hookAddress = address(newHooks[i].hook);
            // Hooks.validateHookPermissions(newHooks[i].hook, IHookPermissions(hookAddress).getHookPermissions());
            cellHooks.push(newHooks[i]);
        }
    }

    function _acceptMethods(
        AcceptedMethod[] memory acceptedMethods
    ) private {
        for (uint256 i = 0; i < acceptedMethods.length; ++i) {
            bytes32 approvedMethod = bytes32(bytes20(uint160(acceptedMethods[i].hook))) 
                | (bytes32(acceptedMethods[i].signature) >> 224);

            selectorIsApproved[approvedMethod] = acceptedMethods[i].status;
        }
    }

    function _callOptionalReturn(address callTo, bytes memory data) private {
        assembly ("memory-safe") {
            let success := call(gas(), callTo, 0, add(data, 0x20), mload(data), 0, 0x20)
            returndatacopy(0, 0, returndatasize())

            switch success
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function _callOptionalReturnAndClearActivePool(address callTo, bytes memory data) private {
        assembly ("memory-safe") {
            let success := call(gas(), callTo, 0, add(data, 0x20), mload(data), 0, 0x20)
            tstore(0x00, 0x00) //0x00 = ACTIVE_POOL_SLOT
            returndatacopy(0, 0, returndatasize())

            switch success
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
