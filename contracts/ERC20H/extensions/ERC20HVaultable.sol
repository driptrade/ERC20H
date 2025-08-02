// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20H} from "../ERC20H.sol";
import {IERC20HMirrorVault} from "../interfaces/IERC20HMirrorVault.sol";
import {IERC20HVaultable} from "../interfaces/IERC20HVaultable.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC-20
 * applications.
 */
abstract contract ERC20HVaultable is ERC20H, IERC20HVaultable {
    function depositToVault(uint256 tokenId, uint256 amount) external virtual {
        IERC20HMirrorVault iMirror = IERC20HMirrorVault(_getMirror());

        address owner = iMirror.ownerOf(tokenId);

        (uint256 locked, uint256 bonded, uint256 awaitingUnlock) = lockedBalancesOf(owner);

        // transfer amount to token id owner
        transfer(owner, amount);
        // lock up newly received amount for token id owner
        _lock(owner, amount + locked - bonded - awaitingUnlock);
        // once locked, bond it to the specified token id
        iMirror.bondToVault(owner, tokenId, amount);
    }
}
