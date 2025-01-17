// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {ImmutableState} from "v4-periphery/src/base/ImmutableState.sol";
        

abstract contract SafeCallback is ImmutableState, IUnlockCallback {
    error NotPoolManager();

    constructor(IPoolManager _poolManager) ImmutableState(_poolManager) {}

    modifier onlyByPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    /// @dev We force the onlyByPoolManager modifier by exposing a virtual function after the onlyByPoolManager check.
    function unlockCallback(bytes calldata data) external virtual onlyByPoolManager returns (bytes memory) {
        return _unlockCallback(data);
    }

    function _unlockCallback(bytes calldata data) internal virtual returns (bytes memory);
}
