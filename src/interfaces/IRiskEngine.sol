// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRiskEngine {
    function getRiskScore() external view returns (uint256);
    function calculateRisk(
        uint256 volatility,
        uint256 concentration,
        uint256 leverage,
        uint256 healthFactor
    ) external pure returns (uint256);
}
