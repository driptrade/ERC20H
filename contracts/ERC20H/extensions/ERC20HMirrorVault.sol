// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC20HMirror} from "../ERC20HMirror.sol";
import {IERC20H} from "../interfaces/IERC20H.sol";
import {IERC20HMirrorVault} from "../interfaces/IERC20HMirrorVault.sol";

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
abstract contract ERC20HMirrorVault is ERC20HMirror, IERC20HMirrorVault {
    using SafeERC20 for IERC20;

    struct Vault {
        address releasableBy;
        mapping(address token => uint256) balances;
    }

    mapping(uint256 tokenId => Vault) private _tokenIdVaults;

    mapping(uint256 tokenId => uint256) private _extraBondedTokens;

    event VaultDeposit(address indexed depositer, uint256 indexed tokenId, address indexed token, uint256 amount);

    event VaultWithdraw(address indexed withdrawer, uint256 indexed tokenId, address indexed token, uint256 amount);

    error ERC20HMirrorVaultInvalidDeposit(address token, uint256 deposited, uint256 expected);

    error ERC20HMirrorVaultInvalidTokenIdRange(uint256 startTokenId, uint256 endTokenId);

    error ERC20HMirrorVaultNotWithdrawable(uint256 tokenId);

    error ERC20HMirrorVaultIncorrectWithdrawer(uint256 tokenId, address withdrawer, address allowedWithdrawer);

    error ERC20HMirrorVaultNothingToWithdraw(uint256 tokenId, address token);

    error ERC20HMirrorVaultCouldNotTransferNativeToken(address withdrawer, uint256 amount);

    error ERC20HMirrorVaultCouldNotTransferERC20Token(address withdrawer, address token, uint256 amount);

    error ERC20HMirrorVaultCannotDepositHybridToken(address hybridToken);

    function bondToVault(address to, uint256 tokenId, uint256 amount) external virtual hybridOnly {
        _safeBondToVault(to, tokenId, amount);
    }

    function deposit(address token, uint256 amount, uint256 tokenId) external payable virtual {
        _acceptDepositFunds(token, _safeDeposit(tokenId, token, amount));
    }

    function deposit(address token, uint256 amountPerToken, uint256 startId, uint256 endId) external payable virtual {
        // make sure the range of token ids are for the same tier, and go from low to high
        if (endId <= startId || startId >> 32 != endId >> 32) {
            revert ERC20HMirrorVaultInvalidTokenIdRange(startId, endId);
        }

        uint256 totalNeeded;

        for (uint256 tokenId = startId; tokenId <= endId;) {
            totalNeeded += _safeDeposit(tokenId, token, amountPerToken);

            unchecked { tokenId += 1; }
        }

        _acceptDepositFunds(token, totalNeeded);
    }

    function deposit(address token, uint256 amountPerToken, uint256[] calldata tokenIds) external payable virtual {
        uint256 totalNeeded;

        for (uint256 i = 0; i < tokenIds.length;) {
            totalNeeded += _safeDeposit(tokenIds[i], token, amountPerToken);

            unchecked { i += 1; }
        }

        _acceptDepositFunds(token, totalNeeded);
    }

    function withdraw(uint256 tokenId) external virtual {
        _withdraw(_msgSender(), tokenId, address(0));
    }

    function withdraw(uint256 tokenId, address token) external virtual {
        _withdraw(_msgSender(), tokenId, token);
    }

    function vaultBalanceOf(uint256 tokenId) external view virtual returns (uint256) {
        return _vaultBalanceOf(tokenId, address(0));
    }

    function vaultBalanceOf(uint256 tokenId, address token) external view virtual returns (uint256) {
        return _vaultBalanceOf(tokenId, token);
    }

    /**
     * @dev Bonds an extra `amount` of tokens to `tokenId`.
     */
    function _safeBondToVault(address to, uint256 tokenId, uint256 amount) internal virtual {
        if (_ownerOf(tokenId) != to) {
            revert ERC20HMirrorInvalidTokenId(tokenId);
        }

        _extraBondedTokens[tokenId] += amount;

        IERC20H(hybrid).onERC20HBonded(to, amount);
    }

    /**
     * @dev Deposits `amount` of `token` into the vault for the specific token id.
     * 
     * This function checks that the token id exists before depositing. If it does not exist,
     * this function will no-op.
     * 
     * For native token deposits, call this function with `token` equal to address(0).
     * 
     * @return the amount of funds deposited, or 0 if the token does not exist
     */
    function _safeDeposit(uint256 tokenId, address token, uint256 amount) internal virtual returns (uint256) {
        if (token == hybrid) {
            revert ERC20HMirrorVaultCannotDepositHybridToken(token);
        }
        if (_ownerOf(tokenId) == address(0)) {
            return 0;
        }

        _deposit(tokenId, token, amount);

        emit VaultDeposit(_msgSender(), tokenId, token, amount);

        return amount;
    }

    function _deposit(uint256 tokenId, address token, uint256 amount) internal virtual {
        Vault storage vault = _tokenIdVaults[tokenId];
        vault.balances[token] += amount;
    }

    function _acceptDepositFunds(address token, uint256 amount) internal virtual {
        if (token == address(0)) {
            if (msg.value == 0 || msg.value != amount) {
                revert ERC20HMirrorVaultInvalidDeposit(address(0), msg.value, amount);
            }
        } else if (msg.value > 0) {
            // Cannot have msg.value if the deposit token is not address(0)
            revert ERC20HMirrorVaultInvalidDeposit(token, msg.value, 0);
        } else {
            IERC20(token).safeTransferFrom(_msgSender(), address(this), amount);
        }
    }

    function _withdraw(address withdrawer, uint256 tokenId, address token) internal virtual {
        Vault storage vault = _tokenIdVaults[tokenId];
        address allowedWithdrawer = vault.releasableBy;

        if (allowedWithdrawer == address(0)) {
            revert ERC20HMirrorVaultNotWithdrawable(tokenId);
        } else if (allowedWithdrawer != withdrawer) {
            revert ERC20HMirrorVaultIncorrectWithdrawer(tokenId, withdrawer, allowedWithdrawer);
        }

        uint256 amount = vault.balances[token];
        if (amount == 0) {
            revert ERC20HMirrorVaultNothingToWithdraw(tokenId, token);
        }

        // deduct the entire balance
        delete vault.balances[token];   
        emit VaultWithdraw(withdrawer, tokenId, token, amount);

        // transfer balance to withdrawer
        if (token == address(0)) {
            (bool success,) = payable(withdrawer).call{ value: amount }('');
            if (!success) {
                revert ERC20HMirrorVaultCouldNotTransferNativeToken(withdrawer, amount);
            }
        } else {
            IERC20(token).safeTransfer(withdrawer, amount);
        }
    }

    function _vaultBalanceOf(uint256 tokenId, address token) internal view virtual returns (uint256) {
        return _tokenIdVaults[tokenId].balances[token];
    }

    function _getBondedUnitsForTokenId(uint256 tokenId) internal view override returns (uint256) {
        return _getUnitsForTier(_getTierIdForToken(tokenId)) + _extraBondedTokens[tokenId];
    }

    function _updateAndReleaseAndUnlock(uint256 tokenId, address auth) internal override returns (address, uint256) {
        // number of tokens represented by tokenId
        uint256 bondedUnits = _getBondedUnitsForTokenId(tokenId);

        // must burn to release tokens
        address from = _update(address(0), tokenId, auth);

        // mark the original token owner as the vault withdrawer
        _tokenIdVaults[tokenId].releasableBy = from;

        IERC20H(hybrid).onERC20HUnbonded(from, bondedUnits);

        return (from, bondedUnits);
    }
}

