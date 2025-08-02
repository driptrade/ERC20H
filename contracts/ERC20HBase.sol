// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20H, ERC20HReleasable } from './ERC20H/extensions/ERC20HReleasable.sol';
import { ERC20HVaultable } from './ERC20H/extensions/ERC20HVaultable.sol';

contract ERC20HBase is ERC20HVaultable, ERC20HReleasable {
    uint256 private _maxSupply;

    constructor(
        address initialOwner,
        string memory name,
        string memory symbol,
        uint256 supply,
        uint96 maxUnlockCooldown
    ) ERC20H(initialOwner, name, symbol, maxUnlockCooldown) {
        _maxSupply = supply;

        // initial distribution is to mint all tokens to initialOwner
        _mint(initialOwner, supply);
    }

    function burn(uint256 value) external virtual {
        _burn(_msgSender(), value);
    }

    function maxSupply() public virtual view returns (uint256) {
        return _maxSupply;
    }
}
