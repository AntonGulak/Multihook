// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks, BeforeSwapDeltaLibrary} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta, BalanceDeltaLibrary, toBalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {toBeforeSwapDelta, BeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PackedHook, Multihook, AcceptedMethod, BaseHook} from "../src/Multihook.sol";
import {MockHook} from "../src/test/MockHook.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {GasPriceFeesHook} from "gas-price-hook/src/GasPriceFeesHook.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {GasPriceFeesHook} from "gas-price-hook/src/GasPriceFeesHook.sol";
import {LBP} from "no-hook-lpb/src/LBP.sol";


import {SafeCast} from "v4-core/libraries/SafeCast.sol";

contract MultihookTest is Test, Deployers {
    using SafeCast for *;
    using PoolIdLibrary for PoolId;
    using CurrencyLibrary for Currency;
    using BalanceDeltaLibrary for BalanceDelta;

    Multihook public hook;
    GasPriceFeesHook public gasPriceHook;

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

    function deployMockHooks(uint8 amount) public returns (PackedHook[] memory) {
        PackedHook[] memory newMockHooks = new PackedHook[](amount);
        
        for (uint256 i = 0; i < amount; ++i) {
            address mockHookAddress = address(
            uint160(
                    Hooks.ALL_HOOK_MASK | (i+1) << 20
                )
            );
            deployCodeTo("src/test/MockHook.sol:MockHook", abi.encode(manager), mockHookAddress);
            newMockHooks[i] = PackedHook(IHooks(mockHookAddress), uint96(0x111111111111 * i), 0);
        }

        return newMockHooks;
    }

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


    function setUp() public {
        deployFreshManagerAndRouters();

        address multiHookAddress = address(
            uint160(
                Hooks.ALL_HOOK_MASK
            )
        );

        uint256 activatedHooks = 0;
        uint256 timeout = 0 hours;
        PackedHook[] memory initHooks;
        AcceptedMethod[] memory initAcceptedMethod;
        deployCodeTo(
            "src/Multihook.sol:Multihook",
            abi.encode(manager, initHooks, initAcceptedMethod, activatedHooks, address(this), timeout), multiHookAddress
        );
        hook = Multihook(multiHookAddress);
    }

    function testAfterAddLiquidityZeroValues() public {
        uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;
    
        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        bytes memory empty;
        bytes32 emptySalt;
        BalanceDelta deltaInput = toBalanceDelta(100, -500);
        (bytes4 selector, BalanceDelta deltaResult) = hook.afterAddLiquidity(
            address(this),
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -10,
                tickUpper: 10,
                liquidityDelta: 100,
                salt: emptySalt
            }),
            deltaInput,
            empty
        );
        
        assertEq(deltaResult.amount0(), 0);
        assertEq(deltaResult.amount1(), 0);
    }

    function testAfterAddLiquidity() public {
        uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;
    
        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        BalanceDelta deltaInputHook0 = toBalanceDelta(100, -500);
        BalanceDelta deltaInputHook1 = toBalanceDelta(300, 200);

        MockHook(address(newHooks[0].hook)).setDeltaAfterAddLiquidity(deltaInputHook0);
        MockHook(address(newHooks[1].hook)).setDeltaAfterAddLiquidity(deltaInputHook1);

        BalanceDelta deltaInput = toBalanceDelta(-420, 700);
        bytes memory empty;
        bytes32 emptySalt;
        (bytes4 selector, BalanceDelta deltaResult) = hook.afterAddLiquidity(
            address(this),
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -10,
                tickUpper: 10,
                liquidityDelta: 100,
                salt: emptySalt
            }),
            deltaInput,
            empty
        );

        assertEq(deltaResult.amount0(), deltaInputHook0.amount0() + deltaInputHook1.amount0());
        assertEq(deltaResult.amount1(), deltaInputHook0.amount1() + deltaInputHook1.amount1());
    }

    function testFuzzAfterAddLiquidity(int120 fuzzAmount0Hook0, int120 fuzzAmount1Hook0, int120 fuzzAmount0Hook1, int120 fuzzAmount1Hook1) public {
        uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;

        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod,activatedHooks);
        hook.acceptNewHooks();

        BalanceDelta deltaInputHook0 = toBalanceDelta(fuzzAmount0Hook0, fuzzAmount1Hook0);
        BalanceDelta deltaInputHook1 = toBalanceDelta(fuzzAmount0Hook1, fuzzAmount1Hook1);

        MockHook(address(newHooks[0].hook)).setDeltaAfterAddLiquidity(deltaInputHook0);
        MockHook(address(newHooks[1].hook)).setDeltaAfterAddLiquidity(deltaInputHook1);

        BalanceDelta deltaInput = toBalanceDelta(100, -500);
        bytes memory empty;
        bytes32 emptySalt;

        (bytes4 selector, BalanceDelta deltaResult) = hook.afterAddLiquidity(
            address(this),
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -10,
                tickUpper: 10,
                liquidityDelta: 100,
                salt: emptySalt
            }),
            deltaInput,
            empty
        );

        assertEq(deltaResult.amount0(), deltaInputHook0.amount0() + deltaInputHook1.amount0());
        assertEq(deltaResult.amount1(), deltaInputHook0.amount1() + deltaInputHook1.amount1());
    }

    function testAfterRemoveLiquidityZeroValues() public {
        uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;
    
        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        bytes memory empty;
        bytes32 emptySalt;
        BalanceDelta deltaInput = toBalanceDelta(-500, 200);
        (bytes4 selector, BalanceDelta deltaResult) = hook.afterRemoveLiquidity(
            address(this),
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -10,
                tickUpper: 10,
                liquidityDelta: 100,
                salt: emptySalt
            }),
            deltaInput,
            empty
        );

        assertEq(deltaResult.amount0(), 0);
        assertEq(deltaResult.amount1(), 0);
    }

    function testAfterRemoveLiquidity() public {
        uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;
    
        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod,activatedHooks);
        hook.acceptNewHooks();

        BalanceDelta deltaInputHook0 = toBalanceDelta(100, -500);
        BalanceDelta deltaInputHook1 = toBalanceDelta(300, 200);

        MockHook(address(newHooks[0].hook)).setDeltaAfterRemoveLiquidity(deltaInputHook0);
        MockHook(address(newHooks[1].hook)).setDeltaAfterRemoveLiquidity(deltaInputHook1);

        BalanceDelta deltaInput = toBalanceDelta(-500, 100);
        bytes memory empty;
        bytes32 emptySalt;
        (bytes4 selector, BalanceDelta deltaResult) = hook.afterRemoveLiquidity(
            address(this),
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -10,
                tickUpper: 10,
                liquidityDelta: 100,
                salt: emptySalt
            }),
            deltaInput,
            empty
        );
        
        assertEq(deltaResult.amount0(), deltaInputHook0.amount0() + deltaInputHook1.amount0());
        assertEq(deltaResult.amount1(), deltaInputHook0.amount1() + deltaInputHook1.amount1());
    }

    function testFuzzAfterRemoveLiquidity(int120 fuzzAmount0Hook0, int120 fuzzAmount1Hook0, int120 fuzzAmount0Hook1, int120 fuzzAmount1Hook1) public {
        uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;

        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        BalanceDelta deltaInputHook0 = toBalanceDelta(fuzzAmount0Hook0, fuzzAmount1Hook0);
        BalanceDelta deltaInputHook1 = toBalanceDelta(fuzzAmount0Hook1, fuzzAmount1Hook1);

        MockHook(address(newHooks[0].hook)).setDeltaAfterRemoveLiquidity(deltaInputHook0);
        MockHook(address(newHooks[1].hook)).setDeltaAfterRemoveLiquidity(deltaInputHook1);

        BalanceDelta deltaInput = toBalanceDelta(100, -500);
        bytes memory empty;
        bytes32 emptySalt;

        (bytes4 selector, BalanceDelta deltaResult) = hook.afterRemoveLiquidity(
            address(this),
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -10,
                tickUpper: 10,
                liquidityDelta: 100,
                salt: emptySalt
            }),
            deltaInput,
            empty
        );

        assertEq(deltaResult.amount0(), deltaInputHook0.amount0() + deltaInputHook1.amount0());
        assertEq(deltaResult.amount1(), deltaInputHook0.amount1() + deltaInputHook1.amount1());
    }

    function testBeforeSwapZeroValue() public {
        uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;
    
        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        bytes memory empty;
        bytes32 emptySalt;
        BalanceDelta deltaInput = toBalanceDelta(100, -500);
        (bytes4 signature, BeforeSwapDelta beforeDeltaResult, uint24 lpFeeOverride) = hook.beforeSwap(
            address(this),
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 1000,
                sqrtPriceLimitX96: 0
            }),
            empty
        );
        
        assertEq(BeforeSwapDeltaLibrary.getSpecifiedDelta(beforeDeltaResult), 0);
        assertEq(BeforeSwapDeltaLibrary.getUnspecifiedDelta(beforeDeltaResult), 0);
    }

    function testBeforeSwapFuzzy(int120 fuzzAmount0Spec, int120 fuzzAmount0Unspec, int120 fuzzAmount1Spec, int120 fuzzAmount1Unspec) public {
        uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;

        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        BeforeSwapDelta beforeSwapDelta0 = toBeforeSwapDelta(fuzzAmount0Spec, fuzzAmount0Unspec);
        BeforeSwapDelta beforeSwapDelta1 = toBeforeSwapDelta(fuzzAmount1Spec, fuzzAmount1Unspec);
        
        MockHook(address(newHooks[0].hook)).setBeforeSwapDelta(beforeSwapDelta0);
        MockHook(address(newHooks[1].hook)).setBeforeSwapDelta(beforeSwapDelta1);

        bytes memory empty;
        bytes32 emptySalt;
        (bytes4 signature, BeforeSwapDelta beforeDeltaResult, uint24 lpFeeOverride) = hook.beforeSwap(
            address(this),
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 1000,
                sqrtPriceLimitX96: 0
            }),
            empty
        );

        BeforeSwapDelta expectedResult = add(beforeSwapDelta0, beforeSwapDelta1);
        
        assertEq(BeforeSwapDeltaLibrary.getSpecifiedDelta(beforeDeltaResult), BeforeSwapDeltaLibrary.getSpecifiedDelta(expectedResult));
        assertEq(BeforeSwapDeltaLibrary.getUnspecifiedDelta(beforeDeltaResult), BeforeSwapDeltaLibrary.getUnspecifiedDelta(expectedResult));
    }

    function testAfterSwapZeroValue() public {
        uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;
    
        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        bytes memory empty;
        bytes32 emptySalt;
        BalanceDelta deltaInput = toBalanceDelta(100, -500);
        (bytes4 signature, int128 deltaUnspecified) = hook.afterSwap(
            address(this),
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 1000,
                sqrtPriceLimitX96: 0
            }),
            deltaInput,
            empty
        );
        
        assertEq(deltaUnspecified, 0);
    }

    function testAfterSwapFuzzy(int120 fuzzDeltaUnspecified0, int120 fuzzDeltaUnspecified1) public {
        uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;

        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        MockHook(address(newHooks[0].hook)).setAfterSwapDeltaUnspecified(fuzzDeltaUnspecified0);
        MockHook(address(newHooks[1].hook)).setAfterSwapDeltaUnspecified(fuzzDeltaUnspecified1);
        

        bytes memory empty;
        bytes32 emptySalt;
        BalanceDelta deltaInput = toBalanceDelta(100, -500);
        (bytes4 signature, int128 deltaUnspecified) = hook.afterSwap(
            address(this),
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 1000,
                sqrtPriceLimitX96: 0
            }),
            deltaInput,
            empty
        );
        
        int128 expectedResult = int128(fuzzDeltaUnspecified0) + int128(fuzzDeltaUnspecified1);
        assertEq(deltaUnspecified, expectedResult);
    }

    function testBeforeInitialize() public {
        uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;

        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        bytes memory empty;
        bytes32 emptySalt;

        (bytes4 selector) = hook.beforeInitialize(
            address(this),
            key,
            1234567890,
            empty
        );

        assertEq(selector, BaseHook.beforeInitialize.selector);
    }

    function testAfterInitialize() public {
        uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;

        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        bytes memory empty;
        bytes32 emptySalt;

        (bytes4 selector) = hook.afterInitialize(
            address(this),
            key,
            1234567890,
            -10,
            empty
        );

        assertEq(selector, BaseHook.afterInitialize.selector);
    }

    function testBeforeAddLiquidity() public {
        uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;

        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        bytes memory empty;
        bytes32 emptySalt;

        (bytes4 selector) = hook.beforeAddLiquidity(
            address(this),
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -10,
                tickUpper: 10,
                liquidityDelta: 100,
                salt: emptySalt
            }),
            empty
        );

        assertEq(selector, BaseHook.beforeAddLiquidity.selector);
    }

    function testBeforeRemoveLiquidity() public {
        uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;

        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        bytes memory empty;
        bytes32 emptySalt;

        (bytes4 selector) = hook.beforeRemoveLiquidity(
            address(this),
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -10,
                tickUpper: 10,
                liquidityDelta: 100,
                salt: emptySalt
            }),
            empty
        );

        assertEq(selector, BaseHook.beforeRemoveLiquidity.selector);
    }

    function testBeforeDonate() public {
        uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;

        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        bytes memory empty;
        bytes32 emptySalt;

        (bytes4 selector) = hook.beforeDonate(
            address(this),
            key,
            100,
            200,
            empty
        );

        assertEq(selector, BaseHook.beforeDonate.selector);
    }

    function testAfterDonate() public {
        uint256 activatedHooks = 276192739754936235766897528674719203563847614478230032138240;

        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        bytes memory empty;
        bytes32 emptySalt;

        (bytes4 selector) = hook.afterDonate(
            address(this),
            key,
            100,
            200,
            empty
        );

        assertEq(selector, BaseHook.afterDonate.selector);
    }

    function testWithDynamicFeeHook() public {
        uint256 activatedHooks = 150650441649280338332058946156983994099793434342399370330112;
        PackedHook[] memory newHooks = new PackedHook[](1);
    
        setUpTestGasPriceFeesHook(address(hook));
        console.log("Kekwqekwqe");
        console.log(address(gasPriceHook));

        newHooks[0] = PackedHook(IHooks(address(gasPriceHook)), uint96(0x111111111111 * 0), 0);

        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        (currency0, currency1) = deployMintAndApprove2Currencies();
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

        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -0.00001 ether,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });

        swapRouter.swap(key, params, testSettings, ZERO_BYTES);
    }
}
