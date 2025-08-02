// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20H} from "./IERC20H.sol";

interface IERC20HVaultable is IERC20H {
	function depositToVault(uint256 tokenId, uint256 amount) external;
}
