// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IAllocationManager.sol";

contract AllocationManager is IAllocationManager, Ownable {
    struct Allocation {
        uint256 lendingPercent;
        uint256 stablePercent;
        uint256 reservePercent;
    }

    Allocation public lowRiskAlloc = Allocation(60, 30, 10);
    Allocation public medRiskAlloc = Allocation(40, 40, 20);
    Allocation public highRiskAlloc = Allocation(25, 55, 20);
    Allocation public stormModeAlloc = Allocation(25, 35, 40);

    event AllocationUpdated(string category, uint256 lendingPercent, uint256 stablePercent, uint256 reservePercent);

    constructor() Ownable(msg.sender) {}

    function updateAllocation(
        string calldata category,
        uint256 lendingPercent,
        uint256 stablePercent,
        uint256 reservePercent
    ) external onlyOwner {
        require(lendingPercent + stablePercent + reservePercent == 100, "Allocation sum must be 100");
        bytes32 categoryHash = keccak256(abi.encodePacked(category));
        
        if (categoryHash == keccak256(abi.encodePacked("low"))) {
            lowRiskAlloc = Allocation(lendingPercent, stablePercent, reservePercent);
        } else if (categoryHash == keccak256(abi.encodePacked("medium"))) {
            medRiskAlloc = Allocation(lendingPercent, stablePercent, reservePercent);
        } else if (categoryHash == keccak256(abi.encodePacked("high"))) {
            highRiskAlloc = Allocation(lendingPercent, stablePercent, reservePercent);
        } else if (categoryHash == keccak256(abi.encodePacked("storm"))) {
            stormModeAlloc = Allocation(lendingPercent, stablePercent, reservePercent);
        } else {
            revert("Invalid category. Use: low, medium, high, storm");
        }
        
        emit AllocationUpdated(category, lendingPercent, stablePercent, reservePercent);
    }

    function getAllocation(uint256 riskScore, bool isStormMode)
        external
        view
        override
        returns (
            uint256 lendingPercent,
            uint256 stablePercent,
            uint256 reservePercent
        )
    {
        if (isStormMode) {
            return (stormModeAlloc.lendingPercent, stormModeAlloc.stablePercent, stormModeAlloc.reservePercent);
        }
        
        if (riskScore <= 35) {
            return (lowRiskAlloc.lendingPercent, lowRiskAlloc.stablePercent, lowRiskAlloc.reservePercent);
        } else if (riskScore <= 75) {
            return (medRiskAlloc.lendingPercent, medRiskAlloc.stablePercent, medRiskAlloc.reservePercent);
        } else {
            return (highRiskAlloc.lendingPercent, highRiskAlloc.stablePercent, highRiskAlloc.reservePercent);
        }
    }
}
