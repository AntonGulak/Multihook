// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta, BalanceDeltaLibrary, toBalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Hook, Multihook} from "../src/Multihook.sol";
import {MockHook} from "../src/test/MockHook.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";

import {GasPriceFeesHook} from "gas-price-hook/src/GasPriceFeesHook.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";

contract MultihookTest is Test, Deployers {
    using PoolIdLibrary for PoolId;
    using CurrencyLibrary for Currency;
    using BalanceDeltaLibrary for BalanceDelta;

    Multihook hook;
    GasPriceFeesHook gasPriceHook;

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

    function deployMockHooks(uint8 amount) public returns (Hook[] memory) {
        Hook[] memory newMockHooks = new Hook[](amount);
        
        for (uint256 i = 0; i < amount; ++i) {
            address mockHookAddress = address(
            uint160(
                    Hooks.ALL_HOOK_MASK | (i+1) << 20
                )
            );
            deployCodeTo("src/test/MockHook.sol:MockHook", abi.encode(manager), mockHookAddress);

            newMockHooks[i] = Hook(IHooks(mockHookAddress), 0);
        }

        return newMockHooks;
    }

    function setUp() public {
        
        deployFreshManagerAndRouters();
        (currency0, currency1) = deployMintAndApprove2Currencies();

        address multiHookAddress = address(
            uint160(
                Hooks.ALL_HOOK_MASK
            )
        );

        setUpTestGasPriceFeesHook(multiHookAddress);

        uint256 activatedHooks = 0;
        uint256 timeout = 0 hours;

        Hook[] memory initHooks;
        deployCodeTo("src/Multihook.sol:Multihook", abi.encode(manager, initHooks, activatedHooks, address(this), timeout), multiHookAddress);
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

        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 100 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
    }

    // function testAfterAddLiquidityZeroValues() public {
    //     uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;
    
    //     Hook[] memory newHooks = deployMockHooks(2);
    //     hook.changeHooks(newHooks, activatedHooks);
    //     hook.acceptNewHooks();

    //     modifyLiquidityRouter.modifyLiquidity(
    //         key,
    //         IPoolManager.ModifyLiquidityParams({
    //             tickLower: -60,
    //             tickUpper: 60,
    //             liquidityDelta: 100 ether,
    //             salt: bytes32(0)
    //         }),
    //         ZERO_BYTES
    //     );
        
    //     BalanceDelta delta = MockHook(address(newHooks[1].hook)).deltaAfterAddLiquidity();
    //     int128 amount0 = delta.amount0();
    //     int128 amount1 = delta.amount1();
    //     assertEq(amount0, 0);
    //     assertEq(amount1, 0);
    // }

    function testAfterAddLiquidity() public {
        // uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;
    
        // Hook[] memory newHooks = deployMockHooks(2);
        // hook.changeHooks(newHooks, activatedHooks);
        // hook.acceptNewHooks();


        // MockHook(address(newHooks[0].hook)).setDeltaAfterAddLiquidity(toBalanceDelta(0, -5));
        // MockHook(address(newHooks[1].hook)).setDeltaAfterAddLiquidity(toBalanceDelta(0, -5));

        // modifyLiquidityRouter.modifyLiquidity(
        //     key,
        //     IPoolManager.ModifyLiquidityParams({
        //         tickLower: -60,
        //         tickUpper: 60,
        //         liquidityDelta: 100 ether,
        //         salt: bytes32(0)
        //     }),
        //     ZERO_BYTES
        // );

        // BalanceDelta delta = MockHook(address(newHooks[1].hook)).deltaAfterAddLiquidity();
        // int128 amount0 = delta.amount0();
        // int128 amount1 = delta.amount1();
        // assertEq(amount0, 0);
        // assertEq(amount1, -10);
    }

    // function test_feeUpdatesWithGasPrice() public {
    //     uint256 activatedHooks = 150650441649280338332058946156983994099793434342399370330112;
    //     Hook[] memory newHooks = new Hook[](1);
    //     newHooks[0] = Hook(IHooks(address(gasPriceHook)), 0);

    //     hook.changeHooks(newHooks, activatedHooks);
    //     hook.acceptNewHooks();

    //     modifyLiquidityRouter.modifyLiquidity(
    //         key,
    //         IPoolManager.ModifyLiquidityParams({
    //             tickLower: -60,
    //             tickUpper: 60,
    //             liquidityDelta: 100 ether,
    //             salt: bytes32(0)
    //         }),
    //         ZERO_BYTES
    //     );

    //     PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
    //         .TestSettings({takeClaims: false, settleUsingBurn: false});

    //     IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
    //         zeroForOne: true,
    //         amountSpecified: -0.00001 ether,
    //         sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
    //     });

    //     swapRouter.swap(key, params, testSettings, ZERO_BYTES);
    // }
}
