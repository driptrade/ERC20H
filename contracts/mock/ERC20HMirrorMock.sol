// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20HMirror } from '../ERC20HMirror.sol';
import { IERC20H } from '../interfaces/IERC20H.sol';

interface IERC20HMintable {
    function burn(address owner, uint256 value) external returns (bool);
}

contract ERC20HMirrorMock is ERC20HMirror {
    struct TierInfoDebug {
        bytes32 uriHash;
        uint32 nextTokenIdSuffix;
        uint32 maxSupply;
        uint32 totalSupply;
        uint128 units;
        uint16 tierId;
        bool active;
        string uri;
    }

    constructor(address initialOwner, address hybrid) ERC20HMirror(initialOwner, hybrid) {}

    function bond(address to, uint256 tokenId) external override {
        if (!_msgSenderIsHybrid()) {
            _checkAuthorized(to, _msgSender(), tokenId);
        }

        _safeMint(to, tokenId);
    }

    function burn(uint256 tokenId) external virtual {
        _burn(tokenId);
    }

    function getTier(uint16 tierId) external view virtual returns (TierInfoDebug memory) {
        TierInfo storage info = _getTierUnsafe(tierId);

        return TierInfoDebug(
            info.uriHash,
            info.nextTokenIdSuffix,
            info.maxSupply,
            info.totalSupply,
            info.units,
            info.tierId,
            info.active,
            _getUri(info.uriHash)
        );
    }

    function _updateAndTransfer(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        // number of tokens represented by tokenId)
        uint256 bondedUnits = _getUnitsForTier(_getTierIdForToken(tokenId));

        address from = _update(to, tokenId, auth);

        bool success;
        if (to == address(0)) {
            success = IERC20HMintable(hybrid).burn(from, bondedUnits);
        } else {
            success = IERC20H(hybrid).transferFrom(from, to, bondedUnits);
        }

        if (!success) {
            revert ERC20HMirrorFailedToTransferBondedTokens(tokenId, from, to);
        }

        return from;
    }
}
