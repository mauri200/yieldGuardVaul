// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAllocationManager {
    function getAllocation(uint256 riskScore, bool isStormMode)
        external
        view
        returns (
            uint256 lendingPercent,
            uint256 stablePercent,
            uint256 reservePercent
        );
}
