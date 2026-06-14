// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./AllocationManager.sol";
import "./StormController.sol";
import "./ReserveVault.sol";
import "./strategies/BaseStrategy.sol";

contract StrategyRouter is Ownable {
    using SafeERC20 for IERC20;

    address public vault;
    AllocationManager public allocationManager;
    StormController public stormController;
    ReserveVault public reserveVault;
    PriceOracle public oracle;

    // Fixed Strategies for easy MVP routing
    BaseStrategy public lendingStrategy;
    BaseStrategy public collateralYieldStrategy;
    BaseStrategy public stableYieldStrategy;
    BaseStrategy public defensiveStrategy;

    // Dynamic strategy registry
    mapping(address => bool) public isStrategyRegistered;
    address[] public registeredStrategies;

    address public usdcToken;
    address[] public supportedStocks;
    mapping(address => bool) public isStock;

    event StrategyDeposited(address indexed strategy, address indexed token, uint256 amount);
    event StrategyWithdrawn(address indexed strategy, address indexed token, uint256 amount);
    event Rebalanced();
    event StrategyAdded(address indexed strategy);
    event StrategyRemoved(address indexed strategy);

    modifier onlyVault() {
        require(msg.sender == vault || msg.sender == owner(), "Router: only vault or owner");
        _;
    }

    constructor(
        address _allocationManager,
        address _stormController,
        address _reserveVault,
        address _oracle,
        address _usdcToken,
        address[] memory _stocks
    ) Ownable(msg.sender) {
        allocationManager = AllocationManager(_allocationManager);
        stormController = StormController(_stormController);
        reserveVault = ReserveVault(_reserveVault);
        oracle = PriceOracle(_oracle);
        usdcToken = _usdcToken;
        for (uint256 i = 0; i < _stocks.length; i++) {
            supportedStocks.push(_stocks[i]);
            isStock[_stocks[i]] = true;
        }
    }

    function setVault(address _vault) external onlyOwner {
        vault = _vault;
    }

    function setStrategies(
        address _lending,
        address _collateral,
        address _stable,
        address _defensive
    ) external onlyOwner {
        lendingStrategy = BaseStrategy(_lending);
        collateralYieldStrategy = BaseStrategy(_collateral);
        stableYieldStrategy = BaseStrategy(_stable);
        defensiveStrategy = BaseStrategy(_defensive);

        // Approve tokens to strategies
        IERC20(usdcToken).approve(_lending, type(uint256).max);
        IERC20(usdcToken).approve(_stable, type(uint256).max);
        IERC20(usdcToken).approve(_defensive, type(uint256).max);

        for (uint256 i = 0; i < supportedStocks.length; i++) {
            IERC20(supportedStocks[i]).approve(_collateral, type(uint256).max);
        }

        // Register default strategies in list
        if (!isStrategyRegistered[_lending]) {
            isStrategyRegistered[_lending] = true;
            registeredStrategies.push(_lending);
        }
        if (!isStrategyRegistered[_collateral]) {
            isStrategyRegistered[_collateral] = true;
            registeredStrategies.push(_collateral);
        }
        if (!isStrategyRegistered[_stable]) {
            isStrategyRegistered[_stable] = true;
            registeredStrategies.push(_stable);
        }
        if (!isStrategyRegistered[_defensive]) {
            isStrategyRegistered[_defensive] = true;
            registeredStrategies.push(_defensive);
        }
    }

    function addStrategy(address strategy) external onlyOwner {
        require(strategy != address(0), "Router: invalid strategy");
        require(!isStrategyRegistered[strategy], "Router: strategy already registered");
        isStrategyRegistered[strategy] = true;
        registeredStrategies.push(strategy);
        emit StrategyAdded(strategy);
    }

    function removeStrategy(address strategy) external onlyOwner {
        require(isStrategyRegistered[strategy], "Router: strategy not registered");
        isStrategyRegistered[strategy] = false;
        for (uint256 i = 0; i < registeredStrategies.length; i++) {
            if (registeredStrategies[i] == strategy) {
                registeredStrategies[i] = registeredStrategies[registeredStrategies.length - 1];
                registeredStrategies.pop();
                break;
            }
        }
        emit StrategyRemoved(strategy);
    }

    function deposit(address token, uint256 amount) external onlyVault {
        allocate(token, amount);
    }

    function allocate(address token, uint256 amount) public onlyVault {
        if (amount == 0) return;

        // If tokens are in router already, we don't transfer, else we transfer
        if (IERC20(token).balanceOf(address(this)) < amount) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        uint256 riskScore = stormController.riskEngine().getRiskScore();
        bool stormActive = stormController.isStormMode();
        (uint256 lendingPct, uint256 stablePct, uint256 reservePct) = allocationManager.getAllocation(riskScore, stormActive);

        if (isStock[token]) {
            uint256 reserveAmt = (amount * reservePct) / 100;
            uint256 strategyAmt = amount - reserveAmt;

            if (reserveAmt > 0) {
                IERC20(token).safeTransfer(address(reserveVault), reserveAmt);
            }
            if (strategyAmt > 0 && address(collateralYieldStrategy) != address(0)) {
                collateralYieldStrategy.deposit(token, strategyAmt);
                emit StrategyDeposited(address(collateralYieldStrategy), token, strategyAmt);
            }
        } else if (token == usdcToken) {
            uint256 reserveAmt = (amount * reservePct) / 100;
            uint256 strategyAmt = amount - reserveAmt;

            if (reserveAmt > 0) {
                IERC20(token).safeTransfer(address(reserveVault), reserveAmt);
            }

            if (strategyAmt > 0) {
                if (stormActive) {
                    uint256 defensiveAmt = (strategyAmt * 60) / 100;
                    uint256 stableAmt = strategyAmt - defensiveAmt;

                    if (defensiveAmt > 0 && address(defensiveStrategy) != address(0)) {
                        defensiveStrategy.deposit(token, defensiveAmt);
                        emit StrategyDeposited(address(defensiveStrategy), token, defensiveAmt);
                    }
                    if (stableAmt > 0 && address(stableYieldStrategy) != address(0)) {
                        stableYieldStrategy.deposit(token, stableAmt);
                        emit StrategyDeposited(address(stableYieldStrategy), token, stableAmt);
                    }
                } else {
                    uint256 totalStrategyPct = lendingPct + stablePct;
                    if (totalStrategyPct > 0) {
                        uint256 lendingAmt = (strategyAmt * lendingPct) / totalStrategyPct;
                        uint256 stableAmt = strategyAmt - lendingAmt;

                        if (lendingAmt > 0 && address(lendingStrategy) != address(0)) {
                            lendingStrategy.deposit(token, lendingAmt);
                            emit StrategyDeposited(address(lendingStrategy), token, lendingAmt);
                        }
                        if (stableAmt > 0 && address(stableYieldStrategy) != address(0)) {
                            stableYieldStrategy.deposit(token, stableAmt);
                            emit StrategyDeposited(address(stableYieldStrategy), token, stableAmt);
                        }
                    }
                }
            }
        }
    }

    function withdraw(address token, address to, uint256 amount) external onlyVault {
        if (amount == 0) return;

        uint256 reserveBal = IERC20(token).balanceOf(address(reserveVault));
        if (reserveBal >= amount) {
            reserveVault.withdraw(token, to, amount);
            return;
        }

        if (reserveBal > 0) {
            reserveVault.withdraw(token, address(this), reserveBal);
        }

        uint256 needed = amount - reserveBal;

        if (isStock[token]) {
            if (address(collateralYieldStrategy) != address(0)) {
                collateralYieldStrategy.withdraw(token, address(this), needed);
            }
        } else if (token == usdcToken) {
            uint256 pulled = 0;
            
            if (address(defensiveStrategy) != address(0)) {
                uint256 initialBal = IERC20(token).balanceOf(address(this));
                defensiveStrategy.withdraw(token, address(this), needed - pulled);
                pulled += (IERC20(token).balanceOf(address(this)) - initialBal);
            }

            if (pulled < needed && address(lendingStrategy) != address(0)) {
                uint256 initialBal = IERC20(token).balanceOf(address(this));
                lendingStrategy.withdraw(token, address(this), needed - pulled);
                pulled += (IERC20(token).balanceOf(address(this)) - initialBal);
            }

            if (pulled < needed && address(stableYieldStrategy) != address(0)) {
                uint256 initialBal = IERC20(token).balanceOf(address(this));
                stableYieldStrategy.withdraw(token, address(this), needed - pulled);
                pulled += (IERC20(token).balanceOf(address(this)) - initialBal);
            }
        }

        uint256 currentBal = IERC20(token).balanceOf(address(this));
        uint256 finalSend = currentBal > amount ? amount : currentBal;
        if (finalSend > 0) {
            IERC20(token).safeTransfer(to, finalSend);
        }
    }

    function handleStormMode(bool active) external {
        require(msg.sender == address(stormController) || msg.sender == owner(), "Router: unauthorized call");
        if (active) {
            rebalance();
        }
    }

    function rebalance() public {
        if (address(lendingStrategy) != address(0)) {
            lendingStrategy.withdraw(usdcToken, address(this), type(uint256).max);
        }
        if (address(stableYieldStrategy) != address(0)) {
            stableYieldStrategy.withdraw(usdcToken, address(this), type(uint256).max);
        }
        if (address(defensiveStrategy) != address(0)) {
            defensiveStrategy.withdraw(usdcToken, address(this), type(uint256).max);
        }

        uint256 usdcBal = IERC20(usdcToken).balanceOf(address(this));
        if (usdcBal > 0) {
            bool stormActive = stormController.isStormMode();
            uint256 riskScore = stormController.riskEngine().getRiskScore();
            (uint256 lendingPct, uint256 stablePct, uint256 reservePct) = allocationManager.getAllocation(riskScore, stormActive);

            uint256 reserveAmt = (usdcBal * reservePct) / 100;
            uint256 strategyAmt = usdcBal - reserveAmt;

            if (reserveAmt > 0) {
                IERC20(usdcToken).safeTransfer(address(reserveVault), reserveAmt);
            }

            if (strategyAmt > 0) {
                if (stormActive) {
                    uint256 defensiveAmt = (strategyAmt * 60) / 100;
                    uint256 stableAmt = strategyAmt - defensiveAmt;
                    if (defensiveAmt > 0) defensiveStrategy.deposit(usdcToken, defensiveAmt);
                    if (stableAmt > 0) stableYieldStrategy.deposit(usdcToken, stableAmt);
                } else {
                    uint256 totalStrategyPct = lendingPct + stablePct;
                    if (totalStrategyPct > 0) {
                        uint256 lendingAmt = (strategyAmt * lendingPct) / totalStrategyPct;
                        uint256 stableAmt = strategyAmt - lendingAmt;
                        if (lendingAmt > 0) lendingStrategy.deposit(usdcToken, lendingAmt);
                        if (stableAmt > 0) stableYieldStrategy.deposit(usdcToken, stableAmt);
                    }
                }
            }
        }
        emit Rebalanced();
    }

    function emergencyWithdraw() external onlyOwner {
        if (address(lendingStrategy) != address(0)) {
            lendingStrategy.emergencyWithdraw();
        }
        if (address(collateralYieldStrategy) != address(0)) {
            collateralYieldStrategy.emergencyWithdraw();
        }
        if (address(stableYieldStrategy) != address(0)) {
            stableYieldStrategy.emergencyWithdraw();
        }
        if (address(defensiveStrategy) != address(0)) {
            defensiveStrategy.emergencyWithdraw();
        }
        for (uint256 i = 0; i < registeredStrategies.length; i++) {
            try BaseStrategy(registeredStrategies[i]).emergencyWithdraw() {} catch {}
        }
    }

    function totalAssets() external view returns (uint256) {
        uint256 total = 0;
        if (address(lendingStrategy) != address(0)) total += lendingStrategy.totalAssets();
        if (address(collateralYieldStrategy) != address(0)) total += collateralYieldStrategy.totalAssets();
        if (address(stableYieldStrategy) != address(0)) total += stableYieldStrategy.totalAssets();
        if (address(defensiveStrategy) != address(0)) total += defensiveStrategy.totalAssets();
        return total;
    }
}
