// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20HMirror} from "./IERC20HMirror.sol";

interface IERC20HMirrorVault is IERC20HMirror {
    function bondToVault(address to, uint256 tokenId, uint256 amount) external;

    function deposit(address token, uint256 amount, uint256 tokenId) external payable;

    function deposit(address token, uint256 amountPerToken, uint256 startId, uint256 endId) external payable;

    function deposit(address token, uint256 amountPerToken, uint256[] calldata tokenIds) external payable;

    function withdraw(uint256 tokenId) external;

    function withdraw(uint256 tokenId, address token) external;

    function vaultBalanceOf(uint256 tokenId) external view returns (uint256);

    function vaultBalanceOf(uint256 tokenId, address token) external view returns (uint256);
}
