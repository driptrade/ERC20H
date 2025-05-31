// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20H, ERC20HReleasable } from '../extensions/ERC20HReleasable.sol';

contract ERC20HMock is ERC20HReleasable {
    constructor(
        address initialOwner,
        uint96 maxUnlockCooldown
    ) ERC20H(initialOwner, 'MyToken', 'MTK', maxUnlockCooldown) {}

    function mint(address to, uint256 amount) external virtual {
        _mint(to, amount);
    }

    function burn(address owner, uint256 value) external virtual mirrorOnly returns (bool) {
        _burn(owner, value);
        return true;
    }

    function lockOnly(uint256 value) external virtual {
        (uint256 locked, uint256 bonded, uint256 awaitingUnlock) = lockedBalancesOf(_msgSender());
        _lock(_msgSender(), value + locked - bonded - awaitingUnlock);
    }
}
