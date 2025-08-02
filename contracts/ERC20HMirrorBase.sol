// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC20H, ERC20HMirror, ERC20HMirrorVault } from './ERC20H/extensions/ERC20HMirrorVault.sol';
import { IERC20HMirror } from './ERC20H/interfaces/IERC20HMirror.sol';

contract ERC20HMirrorBase is ERC20HMirrorVault {
    using Strings for uint256;

    struct UriConfig {
        bool iterative;
        string extension;
    }

    mapping(bytes32 uriHash => UriConfig) private _uriConfigs;

    constructor(
        address initialOwner,
        address hybrid,
        string memory nameOverride,
        string memory symbolOverride
    ) ERC20HMirror(initialOwner, hybrid) {
        if (bytes(nameOverride).length > 0) {
            _setName(nameOverride);
        }
        if (bytes(symbolOverride).length > 0) {
            _setSymbol(symbolOverride);
        }
    }

    function setTierURI(
        uint16 tierId,
        string calldata uri,
        string calldata extension,
        bool iterative
    ) external onlyOwner {
        bytes32 uriHash = _setUriHash(uri);
        _uriConfigs[uriHash] = UriConfig(iterative, extension);
        TierInfo storage tier = _getTierUnsafe(tierId);
        tier.uriHash = uriHash;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        uint16 tokenTierId = _getTierIdForToken(tokenId);
        bytes32 uriHash = _getTierUnsafe(tokenTierId).uriHash;
        string memory uri = _getUri(uriHash);

        if (bytes(uri).length > 0) {
            UriConfig memory config = _uriConfigs[uriHash];
            if (config.iterative) {
                return string(abi.encodePacked(uri, uint256(uint32(tokenId)).toString(), config.extension));
            } else {
                return string(abi.encodePacked(uri, config.extension));
            }
        }

        return "";
    }
}
