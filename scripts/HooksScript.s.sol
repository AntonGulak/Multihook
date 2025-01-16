// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * This script replicates the logic:
 *  1) Activating/deactivating hooks via 20-bit slices for each method.
 *  2) Handling a hook queue (4 bits) for method ordering.
 *  3) Validating that no collisions occur among active hooks in the same queue position.
 */

import "forge-std/Script.sol";
import "forge-std/console.sol";

contract HooksScript is Script {
    // We assume EXACTLY 3 hooks total => valid hook IDs = 0..2.
    uint8 public constant TOTAL_HOOKS = 3;

    // 20-bit slice per method => top 4 bits for count, bottom 16 bits for flags.
    uint256 public constant HOOKS_COUNT_MASK = 0xF0000;  // top 4 bits
    uint256 public constant HOOKS_BIT_MASK   = 0x0FFFF;  // bottom 16 bits

    uint8 public constant HOOKS_COUNT_MASK_SIZE = 4;   // 4 bits for the count
    uint8 public constant HOOKS_BIT_MASK_SIZE   = 16;  // 16 bits for flags
    uint8 public constant MAX_HOOKS_COUNT       = 16;  // We only use 3, but 16 bits are possible

    /**
     * Each method occupies a unique 20-bit interval in a big integer `activatedHooks`.
     */
    uint256 public constant BEFORE_INITIALIZE_BIT_SHIFT = 
        (8 * HOOKS_COUNT_MASK_SIZE + 9 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE; 
    uint256 public constant AFTER_INITIALIZE_BIT_SHIFT = 
        (7 * HOOKS_COUNT_MASK_SIZE + 8 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE; 
    uint256 public constant BEFORE_ADD_LIQUIDITY_BIT_SHIFT = 
        (6 * HOOKS_COUNT_MASK_SIZE + 7 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE; 
    uint256 public constant AFTER_ADD_LIQUIDITY_BIT_SHIFT  = 
        (5 * HOOKS_COUNT_MASK_SIZE + 6 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE; 
    uint256 public constant BEFORE_REMOVE_LIQUIDITY_BIT_SHIFT = 
        (4 * HOOKS_COUNT_MASK_SIZE + 5 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE; 
    uint256 public constant AFTER_REMOVE_LIQUIDITY_BIT_SHIFT  = 
        (3 * HOOKS_COUNT_MASK_SIZE + 4 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE; 
    uint256 public constant BEFORE_SWAP_BIT_SHIFT = 
        (2 * HOOKS_COUNT_MASK_SIZE + 3 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE; 
    uint256 public constant AFTER_SWAP_BIT_SHIFT  = 
        (1 * HOOKS_COUNT_MASK_SIZE + 2 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE; 
    uint256 public constant BEFORE_DONATE_BIT_SHIFT = 
        (0 * HOOKS_COUNT_MASK_SIZE + 1 * HOOKS_BIT_MASK_SIZE) + HOOKS_COUNT_MASK_SIZE; 
    uint256 public constant AFTER_DONATE_BIT_SHIFT  = 0; // last 20-bit slice

    enum HookMethod {
        BEFORE_INITIALIZE,
        AFTER_INITIALIZE,
        BEFORE_ADD_LIQUIDITY,
        AFTER_ADD_LIQUIDITY,
        BEFORE_REMOVE_LIQUIDITY,
        AFTER_REMOVE_LIQUIDITY,
        BEFORE_SWAP,
        AFTER_SWAP,
        BEFORE_DONATE,
        AFTER_DONATE
    }

    function getHookBitmaskShift(HookMethod method) public pure returns (uint256) {
        if (method == HookMethod.BEFORE_INITIALIZE)      return BEFORE_INITIALIZE_BIT_SHIFT;
        if (method == HookMethod.AFTER_INITIALIZE)       return AFTER_INITIALIZE_BIT_SHIFT;
        if (method == HookMethod.BEFORE_ADD_LIQUIDITY)   return BEFORE_ADD_LIQUIDITY_BIT_SHIFT;
        if (method == HookMethod.AFTER_ADD_LIQUIDITY)    return AFTER_ADD_LIQUIDITY_BIT_SHIFT;
        if (method == HookMethod.BEFORE_REMOVE_LIQUIDITY)return BEFORE_REMOVE_LIQUIDITY_BIT_SHIFT;
        if (method == HookMethod.AFTER_REMOVE_LIQUIDITY) return AFTER_REMOVE_LIQUIDITY_BIT_SHIFT;
        if (method == HookMethod.BEFORE_SWAP)            return BEFORE_SWAP_BIT_SHIFT;
        if (method == HookMethod.AFTER_SWAP)             return AFTER_SWAP_BIT_SHIFT;
        if (method == HookMethod.BEFORE_DONATE)          return BEFORE_DONATE_BIT_SHIFT;
        if (method == HookMethod.AFTER_DONATE)           return AFTER_DONATE_BIT_SHIFT;
        revert("Invalid HookMethod");
    }

    function countActivatedHooks(uint16 flags16) public pure returns (uint8) {
        uint8 count;
        for (uint8 i = 0; i < 16; i++) {
            if ((flags16 & (1 << i)) != 0) {
                count++;
            }
        }
        return count;
    }

    /**
     * Activates or deactivates a set of methods for a given hookId in `activatedHooks`.
     * @param methods      array of HookMethod
     * @param active       array of bool (same length as `methods`)
     * @param currentHooks the current global bitmask
     * @param hookId       which bit (0..15) to set/unset in the 16-bit flags
     */
    function activateHooks(
        HookMethod[] memory methods,
        bool[] memory active,
        uint256 currentHooks,
        uint8 hookId
    ) public pure returns (uint256) {
        require(methods.length == active.length, "Arrays length mismatch");
        uint256 newHooks = currentHooks;

        for (uint256 i = 0; i < methods.length; i++) {
            HookMethod method = methods[i];
            bool isActive = active[i];

            uint256 shift = getHookBitmaskShift(method);
            // Extract the 20-bit slice for this method
            uint256 interval20 = (newHooks >> shift) & 0xFFFFF;

            // Lower 16 bits -> flags, top 4 bits -> count
            uint16 flags16 = uint16(interval20 & 0xFFFF);
            // bitPos = 15 - hookId
            uint16 bitPos = uint16(15 - hookId);

            if (isActive) {
                flags16 = flags16 | uint16(1 << bitPos);
            } else {
                flags16 = flags16 & ~uint16(1 << bitPos);
            }

            // Recount how many bits are set
            uint8 newCount = countActivatedHooks(flags16);
            uint256 newInterval20 = (uint256(newCount) << 16) | flags16;

            // Clear the old 20 bits, then put the new 20 bits
            newHooks =
                (newHooks & ~(uint256(0xFFFFF) << shift)) |
                (newInterval20 << shift);
        }

        return newHooks;
    }

    function isMethodActiveForHook(
        uint256 activatedHooks,
        uint8 hookId,
        HookMethod method
    ) public pure returns (bool) {
        uint256 shift = getHookBitmaskShift(method);
        uint256 interval20 = (activatedHooks >> shift) & 0xFFFFF;
        uint16 flags16 = uint16(interval20 & 0xFFFF);

        uint16 bitPos = uint16(15 - hookId);
        return (flags16 & uint16(1 << bitPos)) != 0;
    }

    /*****************************************************
     * 2) HOOK QUEUE ORDER (4 bits per method in hookQueue)
     *****************************************************/
    uint256 public constant BEFORE_INITIALIZE_QUEUE_BIT_SHIFT      = 9 * HOOKS_COUNT_MASK_SIZE; // =36
    uint256 public constant AFTER_INITIALIZE_QUEUE_BIT_SHIFT       = 8 * HOOKS_COUNT_MASK_SIZE; // =32
    uint256 public constant BEFORE_ADD_LIQUIDITY_QUEUE_BIT_SHIFT   = 7 * HOOKS_COUNT_MASK_SIZE; // =28
    uint256 public constant AFTER_ADD_LIQUIDITY_QUEUE_BIT_SHIFT    = 6 * HOOKS_COUNT_MASK_SIZE; // =24
    uint256 public constant BEFORE_REMOVE_LIQUIDITY_QUEUE_BIT_SHIFT= 5 * HOOKS_COUNT_MASK_SIZE; // =20
    uint256 public constant AFTER_REMOVE_LIQUIDITY_QUEUE_BIT_SHIFT = 4 * HOOKS_COUNT_MASK_SIZE; // =16
    uint256 public constant BEFORE_SWAP_QUEUE_BIT_SHIFT            = 3 * HOOKS_COUNT_MASK_SIZE; // =12
    uint256 public constant AFTER_SWAP_QUEUE_BIT_SHIFT             = 2 * HOOKS_COUNT_MASK_SIZE; // =8
    uint256 public constant BEFORE_DONATE_QUEUE_BIT_SHIFT          = 1 * HOOKS_COUNT_MASK_SIZE; // =4
    uint256 public constant AFTER_DONATE_QUEUE_BIT_SHIFT           = 0;                         // =0

    function getHookQueueShift(HookMethod method) public pure returns (uint256) {
        if (method == HookMethod.BEFORE_INITIALIZE)      return BEFORE_INITIALIZE_QUEUE_BIT_SHIFT;
        if (method == HookMethod.AFTER_INITIALIZE)       return AFTER_INITIALIZE_QUEUE_BIT_SHIFT;
        if (method == HookMethod.BEFORE_ADD_LIQUIDITY)   return BEFORE_ADD_LIQUIDITY_QUEUE_BIT_SHIFT;
        if (method == HookMethod.AFTER_ADD_LIQUIDITY)    return AFTER_ADD_LIQUIDITY_QUEUE_BIT_SHIFT;
        if (method == HookMethod.BEFORE_REMOVE_LIQUIDITY)return BEFORE_REMOVE_LIQUIDITY_QUEUE_BIT_SHIFT;
        if (method == HookMethod.AFTER_REMOVE_LIQUIDITY) return AFTER_REMOVE_LIQUIDITY_QUEUE_BIT_SHIFT;
        if (method == HookMethod.BEFORE_SWAP)            return BEFORE_SWAP_QUEUE_BIT_SHIFT;
        if (method == HookMethod.AFTER_SWAP)             return AFTER_SWAP_QUEUE_BIT_SHIFT;
        if (method == HookMethod.BEFORE_DONATE)          return BEFORE_DONATE_QUEUE_BIT_SHIFT;
        if (method == HookMethod.AFTER_DONATE)           return AFTER_DONATE_QUEUE_BIT_SHIFT;
        revert("Invalid HookMethod");
    }

    function setHookQueuePosition(
        uint256 currentQueue,
        HookMethod method,
        uint8 position
    ) public view returns (uint256) {
        require(
            position < TOTAL_HOOKS,
            string(
                abi.encodePacked(
                    "Invalid queue position=",
                    toString(position),
                    ". Must be in [0..",
                    toString(TOTAL_HOOKS - 1),
                    "]."
                )
            )
        );

        uint256 shift = getHookQueueShift(method);
        // Clear the old 4 bits
        uint256 mask = uint256(0xF) << shift;
        uint256 newQueue = currentQueue & ~mask;

        // Set the new 4 bits
        newQueue |= (uint256(position) & 0xF) << shift;
        return newQueue;
    }

    function getHookQueuePosition(
        uint256 currentQueue,
        HookMethod method
    ) public pure returns (uint8) {
        uint256 shift = getHookQueueShift(method);
        return uint8((currentQueue >> shift) & 0xF);
    }

    function validateHookQueuesNoCollisions(
        uint256 activatedHooks,
        uint256[] memory hookIds,
        uint256[] memory hookQueues
    ) public view {
        require(hookIds.length == hookQueues.length, "Arrays length mismatch");

        for (uint256 m = 0; m < 10; m++) {
            HookMethod method = HookMethod(m);
            bool[16] memory usedPositions;

            for (uint256 i = 0; i < hookIds.length; i++) {
                uint8 hId = uint8(hookIds[i]);
                if (isMethodActiveForHook(activatedHooks, hId, method)) {
                    uint8 pos = getHookQueuePosition(hookQueues[i], method);
                    if (usedPositions[pos]) {
                        revert(
                            string(
                                abi.encodePacked(
                                    "Queue collision: method=",
                                    toString(m),
                                    ", position=",
                                    toString(pos),
                                    ". Already used by another active hook."
                                )
                            )
                        );
                    }
                    usedPositions[pos] = true;
                }
            }
        }
        console.log("Queue validation passed: no collisions among active hooks.");
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function logActivatedHooks(uint256 activatedHooks) public view {
        console.log("\nDetailed Activation Info:");
        for (uint256 m = 0; m < 10; m++) {
            HookMethod method = HookMethod(m);
            uint256 shift = getHookBitmaskShift(method);
            uint256 interval20 = (activatedHooks >> shift) & 0xFFFFF;

            uint8 count4 = uint8((interval20 >> 16) & 0xF);
            uint16 flags16 = uint16(interval20 & 0xFFFF);

            if (count4 == 0) {
                console.log("-- Method", m, ": none active");
            } else {
                console.log("-- Method", m, ":");
                console.log("   Count:", count4);
                console.log("   Flags16 (binary):", toBinary(flags16));
            }
        }
    }

    function toBinary(uint16 value) public pure returns (string memory) {
        bytes memory result = new bytes(16);
        for (uint8 i = 0; i < 16; i++) {
            // Приведение к uint16 обязательно
            uint16 mask = uint16(1 << (15 - i));
            result[i] = (value & mask) != 0 ? bytes1("1") : bytes1("0");
        }
        return string(result);
    }

    function run() external {
        vm.startBroadcast(); 
        console.log("=== Starting HooksScript run() ===");

        uint256 activatedHooksGlobal = 0;

        uint256[] memory hookIds = new uint256[](3);
        hookIds[0] = 0;
        hookIds[1] = 1;
        hookIds[2] = 2;

        uint256[] memory hookQueues = new uint256[](3);

        // ------------------ Hook #0 ------------------
        {
            console.log("\n-- Activating Hook #0 (hookId=0) --");
            HookMethod[] memory methods = new HookMethod[](3);
            bool[] memory active = new bool[](3);

            methods[0] = HookMethod.AFTER_REMOVE_LIQUIDITY;  active[0] = true;
            methods[1] = HookMethod.BEFORE_SWAP;             active[1] = true;
            methods[2] = HookMethod.AFTER_SWAP;              active[2] = true;

            activatedHooksGlobal = activateHooks(methods, active, activatedHooksGlobal, 0);

            uint256 q0 = 0;
            q0 = setHookQueuePosition(q0, HookMethod.AFTER_REMOVE_LIQUIDITY, 0);
            q0 = setHookQueuePosition(q0, HookMethod.BEFORE_SWAP, 1);
            q0 = setHookQueuePosition(q0, HookMethod.AFTER_SWAP, 2);
            hookQueues[0] = q0;
        }

        // ------------------ Hook #1 ------------------
        {
            console.log("\n-- Activating Hook #1 (hookId=1) --");
            HookMethod[] memory methods = new HookMethod[](3);
            bool[] memory active = new bool[](3);

            methods[0] = HookMethod.BEFORE_INITIALIZE; active[0] = true;
            methods[1] = HookMethod.AFTER_SWAP;        active[1] = true;
            methods[2] = HookMethod.AFTER_DONATE;      active[2] = true;

            activatedHooksGlobal = activateHooks(methods, active, activatedHooksGlobal, 1);

            uint256 q1 = 0;
            q1 = setHookQueuePosition(q1, HookMethod.BEFORE_INITIALIZE, 0);
            q1 = setHookQueuePosition(q1, HookMethod.AFTER_SWAP, 1);
            q1 = setHookQueuePosition(q1, HookMethod.AFTER_DONATE, 2);
            hookQueues[1] = q1;
        }

        // ------------------ Hook #2 ------------------
        {
            console.log("\n-- Activating Hook #2 (hookId=2) --");
            HookMethod[] memory methods = new HookMethod[](3);
            bool[] memory active = new bool[](3);

            methods[0] = HookMethod.BEFORE_ADD_LIQUIDITY; active[0] = true;
            methods[1] = HookMethod.AFTER_ADD_LIQUIDITY;  active[1] = true;
            methods[2] = HookMethod.BEFORE_DONATE;        active[2] = true;

            activatedHooksGlobal = activateHooks(methods, active, activatedHooksGlobal, 2);

            uint256 q2 = 0;
            q2 = setHookQueuePosition(q2, HookMethod.BEFORE_ADD_LIQUIDITY, 0);
            q2 = setHookQueuePosition(q2, HookMethod.AFTER_ADD_LIQUIDITY, 1);
            q2 = setHookQueuePosition(q2, HookMethod.BEFORE_DONATE, 2);
            hookQueues[2] = q2;
        }

        validateHookQueuesNoCollisions(activatedHooksGlobal, hookIds, hookQueues);

        console.log("\nFinal activatedHooksGlobal (decimal) =", activatedHooksGlobal);
        console.log("Final activatedHooksGlobal (hex)     =", toHex(activatedHooksGlobal));

        logActivatedHooks(activatedHooksGlobal);

        console.log("\n=== Done ===");
        vm.stopBroadcast();
    }

    function toHex(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x0";
        }
        bytes memory alphabet = "0123456789abcdef";

        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 4;
        }
        bytes memory str = new bytes(2 + length);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < length; i++) {
            uint256 nibble = value & 0xf;
            str[2 + length - 1 - i] = alphabet[nibble];
            value >>= 4;
        }
        return string(str);
    }
}
