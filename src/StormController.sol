// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RiskEngine.sol";
import "./ReserveVault.sol";

interface IStrategyRouter {
    function handleStormMode(bool active) external;
    function collateralYieldStrategy() external view returns (address);
}

interface ICollateralYieldStrategy {
    function setLTV(uint256 ltv) external;
}

contract StormController is Ownable {
    RiskEngine public riskEngine;
    IStrategyRouter public strategyRouter;
    ReserveVault public reserveVault;

    bool public isStormMode = false;
    bool public manualOverride = false;

    // Thresholds
    uint256 public volatilityThreshold = 50; 
    uint256 public healthFactorThreshold = 1300; 

    // Simulated market health factor (scaled by 1000, e.g. 1800 = 1.8)
    uint256 public simulatedHealthFactor = 1800; 

    event StormModeActivated();
    event StormModeDisabled();
    event ThresholdsUpdated(uint256 volatilityThreshold, uint256 healthFactorThreshold);
    event StrategyRouterUpdated(address router);
    event ReserveVaultUpdated(address reserveVault);
    event SimulatedHealthFactorUpdated(uint256 healthFactor);

    constructor(address _riskEngine) Ownable(msg.sender) {
        riskEngine = RiskEngine(_riskEngine);
    }

    function setStrategyRouter(address _strategyRouter) external onlyOwner {
        strategyRouter = IStrategyRouter(_strategyRouter);
        emit StrategyRouterUpdated(_strategyRouter);
    }

    function setReserveVault(address _reserveVault) external onlyOwner {
        reserveVault = ReserveVault(_reserveVault);
        emit ReserveVaultUpdated(_reserveVault);
    }

    function setThresholds(uint256 _volatilityThreshold, uint256 _healthFactorThreshold) external onlyOwner {
        volatilityThreshold = _volatilityThreshold;
        healthFactorThreshold = _healthFactorThreshold;
        emit ThresholdsUpdated(_volatilityThreshold, _healthFactorThreshold);
    }

    function setSimulatedHealthFactor(uint256 _healthFactor) external onlyOwner {
        simulatedHealthFactor = _healthFactor;
        emit SimulatedHealthFactorUpdated(_healthFactor);
        checkConditions();
    }

    function activateStormMode() public onlyOwner {
        if (!isStormMode) {
            isStormMode = true;
            emit StormModeActivated();
            
            increaseReserve();
            reduceDebt();
            pauseAggressiveStrategies();

            if (address(strategyRouter) != address(0)) {
                strategyRouter.handleStormMode(true);
            }
        }
    }

    function disableStormMode() public onlyOwner {
        if (isStormMode) {
            isStormMode = false;
            emit StormModeDisabled();
            
            if (address(reserveVault) != address(0)) {
                reserveVault.updateReservePercentages(10, 25);
            }
            if (address(strategyRouter) != address(0)) {
                address colStrat = strategyRouter.collateralYieldStrategy();
                if (colStrat != address(0)) {
                    try ICollateralYieldStrategy(colStrat).setLTV(25) {} catch {}
                }
            }

            if (address(strategyRouter) != address(0)) {
                strategyRouter.handleStormMode(false);
            }
        }
    }

    function checkConditions() public returns (bool) {
        uint256 riskScore = riskEngine.getRiskScore();
        uint256 volatility = riskEngine.volatility();
        uint256 healthFactor = simulatedHealthFactor;

        bool shouldBeStorm = manualOverride || 
            (riskScore > 75) || 
            (healthFactor < healthFactorThreshold) || 
            (volatility > volatilityThreshold);

        if (shouldBeStorm && !isStormMode) {
            activateStormMode();
        } else if (!shouldBeStorm && isStormMode) {
            disableStormMode();
        }

        return isStormMode;
    }

    function reduceDebt() public {
        if (address(strategyRouter) != address(0)) {
            address colStrat = strategyRouter.collateralYieldStrategy();
            if (colStrat != address(0)) {
                try ICollateralYieldStrategy(colStrat).setLTV(10) {} catch {}
            }
        }
    }

    function increaseReserve() public {
        if (address(reserveVault) != address(0)) {
            reserveVault.updateReservePercentages(25, 25);
        }
    }

    function pauseAggressiveStrategies() public {
        // Flow redirection is handled on rebalance by StrategyRouter
    }

    function setManualOverride(bool _override) external onlyOwner {
        manualOverride = _override;
        checkConditions();
    }
}
