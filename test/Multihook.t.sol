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
import {PackedHook, Multihook, AcceptedMethod, BaseHook, MultiHookInitParams} from "../src/Multihook.sol";
import {MockHook} from "../src/test/MockHook.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";

import {HooksScript} from "../scripts/HooksScript.s.sol";
 
contract MultihookTest is Test, Deployers {
    using SafeCast for *;
    using PoolIdLibrary for PoolId;
    using CurrencyLibrary for Currency;
    using BalanceDeltaLibrary for BalanceDelta;

    Multihook public hook;
    HooksScript public helper; 


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

    function setUp() public {
        deployFreshManagerAndRouters();
        (currency0, currency1) = deployMintAndApprove2Currencies();

        address multiHookAddress = address(
            uint160(Hooks.ALL_HOOK_MASK)
        );

        helper = new HooksScript();

        uint256 activatedHooks = 0;
        uint256 timeout = 0 hours;
        PackedHook[] memory initHooks;
        AcceptedMethod[] memory initAcceptedMethod;

        deployCodeTo(
            "src/Multihook.sol:Multihook",
            abi.encode(
                MultiHookInitParams(
                    manager,
                    currency0,
                    currency1,
                    initHooks,
                    initAcceptedMethod,
                    activatedHooks,
                    address(this),
                    timeout
                )
            ),
            multiHookAddress
        );
        hook = Multihook(multiHookAddress);

        key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,    
            tickSpacing: 60,
            hooks: IHooks(multiHookAddress)
        });
    }

    // --------------------------------------------------------------------------------------
    // AFTER_ADD_LIQUIDITY tests
    // --------------------------------------------------------------------------------------

    function testAfterAddLiquidityZeroValues() public {
        // (!!!) Generating activatedHooks dynamically
        HooksScript.HookMethod[] memory methods = new HooksScript.HookMethod[](1);
        bool[] memory active = new bool[](1);

        methods[0] = HooksScript.HookMethod.AFTER_ADD_LIQUIDITY;
        active[0] = true;

        uint256 activatedHooks; // starts from 0
        // Activating this method for 2 different hookIds: 0 and 1
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 0);
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 1);

        // Next is the usual code
        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        // Testing
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
            deltaInput,
            empty
        );
            
        assertEq(deltaResult.amount0(), 0);
        assertEq(deltaResult.amount1(), 0);
    }

    function testAfterAddLiquidity() public {
        HooksScript.HookMethod[] memory methods = new HooksScript.HookMethod[](1);
        bool[] memory active = new bool[](1);

        methods[0] = HooksScript.HookMethod.AFTER_ADD_LIQUIDITY;
        active[0] = true;

        uint256 activatedHooks;
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 0);
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 1);

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
            deltaInput,
            empty
        );

        assertEq(
            deltaResult.amount0(),
            deltaInputHook0.amount0() + deltaInputHook1.amount0()
        );
        assertEq(
            deltaResult.amount1(),
            deltaInputHook0.amount1() + deltaInputHook1.amount1()
        );
    }

    function testFuzzAfterAddLiquidity(
        int120 fuzzAmount0Hook0,
        int120 fuzzAmount1Hook0,
        int120 fuzzAmount0Hook1,
        int120 fuzzAmount1Hook1
    ) public {
        // (!!!) Тоже AFTER_ADD_LIQUIDITY
        HooksScript.HookMethod[] memory methods = new HooksScript.HookMethod[](1);
        bool[] memory active = new bool[](1);

        methods[0] = HooksScript.HookMethod.AFTER_ADD_LIQUIDITY;
        active[0] = true;

        uint256 activatedHooks;
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 0);
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 1);

        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
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
            deltaInput,
            empty
        );

        assertEq(
            deltaResult.amount0(),
            deltaInputHook0.amount0() + deltaInputHook1.amount0()
        );
        assertEq(
            deltaResult.amount1(),
            deltaInputHook0.amount1() + deltaInputHook1.amount1()
        );
    }

    // --------------------------------------------------------------------------------------
    // AFTER_REMOVE_LIQUIDITY tests
    // --------------------------------------------------------------------------------------

    function testAfterRemoveLiquidityZeroValues() public {
        HooksScript.HookMethod[] memory methods = new HooksScript.HookMethod[](1);
        bool[] memory active = new bool[](1);

        methods[0] = HooksScript.HookMethod.AFTER_REMOVE_LIQUIDITY;
        active[0] = true;

        uint256 activatedHooks;
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 0);
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 1);

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
            deltaInput,
            empty
        );

        assertEq(deltaResult.amount0(), 0);
        assertEq(deltaResult.amount1(), 0);
    }

    function testAfterRemoveLiquidity() public {
        HooksScript.HookMethod[] memory methods = new HooksScript.HookMethod[](1);
        bool[] memory active = new bool[](1);

        methods[0] = HooksScript.HookMethod.AFTER_REMOVE_LIQUIDITY;
        active[0] = true;

        uint256 activatedHooks;
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 0);
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 1);

        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
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
            deltaInput,
            empty
        );
        
        assertEq(
            deltaResult.amount0(),
            deltaInputHook0.amount0() + deltaInputHook1.amount0()
        );
        assertEq(
            deltaResult.amount1(),
            deltaInputHook0.amount1() + deltaInputHook1.amount1()
        );
    }

    function testFuzzAfterRemoveLiquidity(
        int120 fuzzAmount0Hook0,
        int120 fuzzAmount1Hook0,
        int120 fuzzAmount0Hook1,
        int120 fuzzAmount1Hook1
    ) public {
        HooksScript.HookMethod[] memory methods = new HooksScript.HookMethod[](1);
        bool[] memory active = new bool[](1);

        methods[0] = HooksScript.HookMethod.AFTER_REMOVE_LIQUIDITY;
        active[0] = true;

        uint256 activatedHooks;
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 0);
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 1);

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
            deltaInput,
            empty
        );

        assertEq(
            deltaResult.amount0(),
            deltaInputHook0.amount0() + deltaInputHook1.amount0()
        );
        assertEq(
            deltaResult.amount1(),
            deltaInputHook0.amount1() + deltaInputHook1.amount1()
        );
    }

    // --------------------------------------------------------------------------------------
    // BEFORE_SWAP tests
    // --------------------------------------------------------------------------------------

    function testBeforeSwapZeroValue() public {
        HooksScript.HookMethod[] memory methods = new HooksScript.HookMethod[](1);
        bool[] memory active = new bool[](1);

        methods[0] = HooksScript.HookMethod.BEFORE_SWAP;
        active[0] = true;

        uint256 activatedHooks;
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 0);
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 1);

        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

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

        assertEq(
            BeforeSwapDeltaLibrary.getSpecifiedDelta(beforeDeltaResult),
            0
        );
        assertEq(
            BeforeSwapDeltaLibrary.getUnspecifiedDelta(beforeDeltaResult),
            0
        );
    }

    function testBeforeSwapFuzzy(
        int120 fuzzAmount0Spec,
        int120 fuzzAmount0Unspec,
        int120 fuzzAmount1Spec,
        int120 fuzzAmount1Unspec
    ) public {
        HooksScript.HookMethod[] memory methods = new HooksScript.HookMethod[](1);
        bool[] memory active = new bool[](1);

        methods[0] = HooksScript.HookMethod.BEFORE_SWAP;
        active[0] = true;

        uint256 activatedHooks;
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 0);
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 1);

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

        assertEq(
            BeforeSwapDeltaLibrary.getSpecifiedDelta(beforeDeltaResult),
            BeforeSwapDeltaLibrary.getSpecifiedDelta(expectedResult)
        );
        assertEq(
            BeforeSwapDeltaLibrary.getUnspecifiedDelta(beforeDeltaResult),
            BeforeSwapDeltaLibrary.getUnspecifiedDelta(expectedResult)
        );
    }

    // --------------------------------------------------------------------------------------
    // AFTER_SWAP tests
    // --------------------------------------------------------------------------------------

    function testAfterSwapZeroValue() public {
        HooksScript.HookMethod[] memory methods = new HooksScript.HookMethod[](1);
        bool[] memory active = new bool[](1);

        methods[0] = HooksScript.HookMethod.AFTER_SWAP;
        active[0] = true;

        uint256 activatedHooks;
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 0);
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 1);

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

    function testAfterSwapFuzzy(
        int120 fuzzDeltaUnspecified0,
        int120 fuzzDeltaUnspecified1
    ) public {
        HooksScript.HookMethod[] memory methods = new HooksScript.HookMethod[](1);
        bool[] memory active = new bool[](1);

        methods[0] = HooksScript.HookMethod.AFTER_SWAP;
        active[0] = true;

        uint256 activatedHooks;
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 0);
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 1);

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

    // --------------------------------------------------------------------------------------
    // BEFORE_INITIALIZE tests
    // --------------------------------------------------------------------------------------

    function testBeforeInitialize() public {
        HooksScript.HookMethod[] memory methods = new HooksScript.HookMethod[](1);
        bool[] memory active = new bool[](1);

        methods[0] = HooksScript.HookMethod.BEFORE_INITIALIZE;
        active[0] = true;

        uint256 activatedHooks;
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 0);
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 1);

        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        (bytes4 selector) = hook.beforeInitialize(
            address(this),
            key,
            1234567890
        );

        assertEq(selector, BaseHook.beforeInitialize.selector);
    }

    // --------------------------------------------------------------------------------------
    // AFTER_INITIALIZE tests
    // --------------------------------------------------------------------------------------

    function testAfterInitialize() public {
        HooksScript.HookMethod[] memory methods = new HooksScript.HookMethod[](1);
        bool[] memory active = new bool[](1);

        methods[0] = HooksScript.HookMethod.AFTER_INITIALIZE;
        active[0] = true;

        uint256 activatedHooks;
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 0);
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 1);

        PackedHook[] memory newHooks = deployMockHooks(2);
        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(newHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();

        (bytes4 selector) = hook.afterInitialize(
            address(this),
            key,
            1234567890,
            -10
        );

        assertEq(selector, BaseHook.afterInitialize.selector);
    }

    // --------------------------------------------------------------------------------------
    // BEFORE_ADD_LIQUIDITY tests
    // --------------------------------------------------------------------------------------

    function testBeforeAddLiquidity() public {
        HooksScript.HookMethod[] memory methods = new HooksScript.HookMethod[](1);
        bool[] memory active = new bool[](1);

        methods[0] = HooksScript.HookMethod.BEFORE_ADD_LIQUIDITY;
        active[0] = true;

        uint256 activatedHooks;
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 0);
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 1);

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

    // // --------------------------------------------------------------------------------------
    // // BEFORE_REMOVE_LIQUIDITY tests
    // // --------------------------------------------------------------------------------------

    function testBeforeRemoveLiquidity() public {
        HooksScript.HookMethod[] memory methods = new HooksScript.HookMethod[](1);
        bool[] memory active = new bool[](1);

        methods[0] = HooksScript.HookMethod.BEFORE_REMOVE_LIQUIDITY;
        active[0] = true;

        uint256 activatedHooks;
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 0);
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 1);

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

    // --------------------------------------------------------------------------------------
    // BEFORE_DONATE tests
    // --------------------------------------------------------------------------------------

    function testBeforeDonate() public {
        HooksScript.HookMethod[] memory methods = new HooksScript.HookMethod[](1);
        bool[] memory active = new bool[](1);

        methods[0] = HooksScript.HookMethod.BEFORE_DONATE;
        active[0] = true;

        uint256 activatedHooks;
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 0);
        activatedHooks = helper.activateHooks(methods, active, activatedHooks, 1);

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

    
    function testComplex() public {
        PackedHook[] memory newMockHooks = new PackedHook[](2);
        address mockHookAddress0 = address(
            uint160(
                Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | (1) << 20
            )
        );
        deployCodeTo("src/test/MockHook.sol:MockHook", abi.encode(manager), mockHookAddress0);
        MockHook mockHook0 = MockHook(mockHookAddress0);
        mockHook0.setHookPermissions(
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: true, 
                afterAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true, 
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            })
        );

        address mockHookAddress1 = address(
            uint160(
                Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_DONATE_FLAG | Hooks.AFTER_INITIALIZE_FLAG | (2) << 20
            )
        );
        deployCodeTo("src/test/MockHook.sol:MockHook", abi.encode(manager), mockHookAddress1);
        MockHook mockHook1 = MockHook(mockHookAddress1);
        mockHook1.setHookPermissions(
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: true,
                beforeAddLiquidity: false, 
                afterAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false, 
                afterSwap: false,
                beforeDonate: true,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            })
        );
       
        uint256 activatedHooks; 
        HooksScript.HookMethod[] memory methods0 = new HooksScript.HookMethod[](3);
        bool[] memory active0 = new bool[](3);

        methods0[0] = HooksScript.HookMethod.AFTER_ADD_LIQUIDITY;
        active0[0] = true;

        methods0[1] = HooksScript.HookMethod.BEFORE_ADD_LIQUIDITY;
        active0[1] = true;

        methods0[2] = HooksScript.HookMethod.BEFORE_SWAP;
        active0[2] = true;

        uint256 q0 = 0;
        q0 = helper.setHookQueuePosition(q0, HooksScript.HookMethod.AFTER_ADD_LIQUIDITY, 1);
        q0 = helper.setHookQueuePosition(q0, HooksScript.HookMethod.BEFORE_ADD_LIQUIDITY, 0);
        q0 = helper.setHookQueuePosition(q0, HooksScript.HookMethod.BEFORE_SWAP, 0);

        activatedHooks = helper.activateHooks(methods0, active0, activatedHooks, 0);

        HooksScript.HookMethod[] memory methods1 = new HooksScript.HookMethod[](3);
        bool[] memory active1 = new bool[](3);

        methods1[0] = HooksScript.HookMethod.AFTER_ADD_LIQUIDITY;
        active1[0] = true;

        methods1[1] = HooksScript.HookMethod.BEFORE_DONATE;
        active1[1] = true;

        methods1[2] = HooksScript.HookMethod.AFTER_INITIALIZE;
        active1[2] = true;

        uint256 q1 = 0;
        q1 = helper.setHookQueuePosition(q1, HooksScript.HookMethod.AFTER_ADD_LIQUIDITY, 0);
        q1 = helper.setHookQueuePosition(q1, HooksScript.HookMethod.AFTER_INITIALIZE, 1);
        q1 = helper.setHookQueuePosition(q1, HooksScript.HookMethod.BEFORE_DONATE, 1);

        activatedHooks = helper.activateHooks(methods1, active1, activatedHooks, 1);

        PackedHook[] memory packedHooks = new PackedHook[](1);
        newMockHooks[0] = PackedHook(IHooks(mockHookAddress0), uint96(q0), 0);
        newMockHooks[1] = PackedHook(IHooks(mockHookAddress1), uint96(q1), 0);

        AcceptedMethod[] memory initAcceptedMethod;
        hook.changeHooks(packedHooks, initAcceptedMethod, activatedHooks);
        hook.acceptNewHooks();
    }
}
