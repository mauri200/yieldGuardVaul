// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRiskEngine.sol";

contract RiskEngine is IRiskEngine, Ownable {
    uint256 public volatility = 20;       // 0-100
    uint256 public concentration = 30;    // 0-100
    uint256 public leverage = 10;         // 0-100
    uint256 public healthFactorRisk = 15;  // 0-100

    event RiskMetricsUpdated(uint256 volatility, uint256 concentration, uint256 leverage, uint256 healthFactorRisk);

    constructor() Ownable(msg.sender) {}

    function updateMetrics(
        uint256 _volatility,
        uint256 _concentration,
        uint256 _leverage,
        uint256 _healthFactorRisk
    ) external onlyOwner {
        require(_volatility <= 100 && _concentration <= 100 && _leverage <= 100 && _healthFactorRisk <= 100, "Metrics must be <= 100");
        volatility = _volatility;
        concentration = _concentration;
        leverage = _leverage;
        healthFactorRisk = _healthFactorRisk;
        emit RiskMetricsUpdated(_volatility, _concentration, _leverage, _healthFactorRisk);
    }

    function getRiskScore() public view override returns (uint256) {
        return calculateRisk(volatility, concentration, leverage, healthFactorRisk);
    }

    function calculateRisk(
        uint256 _volatility,
        uint256 _concentration,
        uint256 _leverage,
        uint256 _healthFactorRisk
    ) public pure override returns (uint256) {
        require(_volatility <= 100 && _concentration <= 100 && _leverage <= 100 && _healthFactorRisk <= 100, "Metrics must be <= 100");
        return (35 * _volatility + 25 * _concentration + 25 * _leverage + 15 * _healthFactorRisk) / 100;
    }

    function calculateConcentration(uint256 largestAssetValue, uint256 totalPortfolioValue) public pure returns (uint256) {
        if (totalPortfolioValue == 0) return 0;
        uint256 score = (largestAssetValue * 100) / totalPortfolioValue;
        return score > 100 ? 100 : score;
    }

    function calculateLeverage(uint256 debtUSD, uint256 equityUSD) public pure returns (uint256) {
        uint256 totalAssetsVal = debtUSD + equityUSD;
        if (totalAssetsVal == 0) return 0;
        uint256 score = (debtUSD * 100) / totalAssetsVal;
        return score > 100 ? 100 : score;
    }

    function calculateHealthFactor(uint256 collateralUSD, uint256 debtUSD) public pure returns (uint256) {
        if (debtUSD == 0) return 0; // 0 risk
        
        // healthFactor = (collateralUSD * 1000) / debtUSD (represented with 3 decimals, e.g. 1500 = 1.5)
        uint256 healthFactor = (collateralUSD * 1000) / debtUSD;
        
        if (healthFactor >= 2000) {
            return 0; // extremely safe, 0 risk score contribution
        } else if (healthFactor <= 1000) {
            return 100; // liquidation threshold, 100 risk score contribution
        } else {
            // scale intermediate health factor between 1.0 (100 risk) and 2.0 (0 risk)
            return ((2000 - healthFactor) * 100) / 1000;
        }
    }
}
