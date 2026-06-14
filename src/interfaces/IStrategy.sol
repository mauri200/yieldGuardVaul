// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStrategy {
    function deposit(address token, uint256 amount) external;
    function withdraw(address token, address to, uint256 amount) external;
    function totalAssets() external view returns (uint256);
    function harvest() external;
    function emergencyWithdraw() external;
}
