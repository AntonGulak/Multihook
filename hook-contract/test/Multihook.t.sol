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

        Hook[] memory initHooks = new Hook[](1);
        initHooks[0] = Hook(address(gasPriceHook));

        deployCodeTo("src/Multihook.sol:Multihook", abi.encode(manager, initHooks, address(this)), multiHookAddress);
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
    }

    function test_withGasPriceHook() public view {
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
