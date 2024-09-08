// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Hook, Multihook} from "../src/Multihook.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";

import {GasPriceFeesHook} from "gas-price-hook/src/GasPriceFeesHook.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";

contract MultihookTest is Test, Deployers {
    using PoolIdLibrary for PoolId;
    using CurrencyLibrary for Currency;

    Multihook hook;
    GasPriceFeesHook gasPriceHook;

    function setUp() public {
        deployFreshManagerAndRouters();
        (currency0, currency1) = deployMintAndApprove2Currencies();

        address multiHookAddress = address(
            uint160(
                Hooks.ALL_HOOK_MASK
            )
        );

        setUpTestGasPriceFeesHook(multiHookAddress);

        uint256 activatedHooks = 150650441649280338332058946156983994099793434342399370330112;

        Hook[] memory initHooks = new Hook[](1);
        initHooks[0] = Hook(address(gasPriceHook), 0);

        deployCodeTo("src/Multihook.sol:Multihook", abi.encode(manager, initHooks, activatedHooks, address(this)), multiHookAddress);
        hook = Multihook(multiHookAddress);

        vm.txGasPrice(10 gwei);
        (key, ) = initPool(
            currency0,
            currency1,
            hook,
            LPFeeLibrary.DYNAMIC_FEE_FLAG,
            SQRT_PRICE_1_1,
            ZERO_BYTES
        );

        // (uint24 hooks_counts, uint24 hooks_flags) = hook.getActivatedHooks(786191, hook.AFTER_DONATE_HOOK_FLAGS(), 0);

        // console.log(hooks_counts);
        // console.log(hooks_flags);
        
        // (hooks_counts, hooks_flags) = hook.getActivatedHooks(824381014016, hook.BEFORE_DONATE_HOOK_FLAGS(), 20);

        // console.log(hooks_counts);
        // console.log(hooks_flags);
    }

    function test_feeUpdatesWithGasPrice() public {
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -0.00001 ether,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });

        swapRouter.swap(key, params, testSettings, ZERO_BYTES);
    }


    //!!!!!!!!
    function setUpTestGasPriceFeesHook(address multiHookAddress) internal {
        address hookAddress = address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG |
                    Hooks.BEFORE_SWAP_FLAG |
                    Hooks.AFTER_SWAP_FLAG
            )
        );

        deployCodeTo("GasPriceFeesHook", abi.encode(multiHookAddress), hookAddress);
        gasPriceHook = GasPriceFeesHook(hookAddress);
    }

}
