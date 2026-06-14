// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseStrategy.sol";
import "./StableYieldStrategy.sol";

contract CollateralYieldStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    address public stableYieldStrategy;
    address public usdcToken;
    uint256 public ltv = 25; // 25% conservative LTV

    // Collateral balances
    mapping(address => uint256) public collateralBalances;
    // Borrowed USDC balances
    mapping(address => uint256) public borrowedUSDC;

    address[] public supportedStocks;
    mapping(address => bool) public isStockSupported;

    event Borrowed(address indexed stock, uint256 stockAmount, uint256 usdcBorrowed);
    event Repaid(address indexed stock, uint256 stockAmount, uint256 usdcRepaid);

    constructor(
        address _strategyRouter,
        address _vault,
        address _oracle,
        address _usdcToken,
        address[] memory _stocks
    ) BaseStrategy(_strategyRouter, _vault, _oracle) {
        usdcToken = _usdcToken;
        for (uint256 i = 0; i < _stocks.length; i++) {
            supportedStocks.push(_stocks[i]);
            isStockSupported[_stocks[i]] = true;
        }
    }

    function setStableYieldStrategy(address _stableYieldStrategy) external onlyOwner {
        stableYieldStrategy = _stableYieldStrategy;
        IERC20(usdcToken).approve(_stableYieldStrategy, type(uint256).max);
    }

    function setLTV(uint256 _ltv) external onlyOwner {
        require(_ltv <= 40, "CollateralYieldStrategy: LTV must be conservative (<= 40%)");
        ltv = _ltv;
    }

    function deposit(address token, uint256 amount) external override onlyRouterOrVault {
        require(isStockSupported[token], "CollateralYieldStrategy: unsupported stock");
        if (amount > 0) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            collateralBalances[token] += amount;

            // Borrow USDC conservatively
            uint256 stockPrice = oracle.getPrice(token); // 18 decimals
            uint8 stockDecimals = getTokenDecimals(token);
            uint256 stockValUSD = (amount * stockPrice) / (10 ** stockDecimals); // 18 decimals

            uint256 borrowUSD = (stockValUSD * ltv) / 100; // 18 decimals
            
            // Convert borrow USD to USDC (6 or 18 decimals)
            uint8 usdcDec = getTokenDecimals(usdcToken);
            uint256 borrowUSDC = borrowUSD / (10 ** (18 - usdcDec));

            if (borrowUSDC > 0) {
                // Simulate borrowing USDC (we can mint it or use local balance)
                MockMintable(usdcToken).mint(address(this), borrowUSDC);
                borrowedUSDC[token] += borrowUSDC;

                // Deposit USDC into StableYieldStrategy
                StableYieldStrategy(stableYieldStrategy).deposit(usdcToken, borrowUSDC);
                emit Borrowed(token, amount, borrowUSDC);
            }
            
            emit Deposited(token, amount);
        }
    }

    function withdraw(address token, address to, uint256 amount) external override onlyRouterOrVault {
        require(isStockSupported[token], "CollateralYieldStrategy: unsupported stock");
        uint256 balance = collateralBalances[token];
        uint256 toWithdraw = amount > balance ? balance : amount;

        if (toWithdraw > 0) {
            // Repay corresponding USDC debt
            uint256 fraction = (toWithdraw * 1e18) / balance;
            uint256 debtToRepay = (borrowedUSDC[token] * fraction) / 1e18;

            if (debtToRepay > 0) {
                // Withdraw USDC from StableYieldStrategy
                StableYieldStrategy(stableYieldStrategy).withdraw(usdcToken, address(this), debtToRepay);
                
                // Simulate repaying: burn the USDC
                MockMintable(usdcToken).burn(debtToRepay);
                borrowedUSDC[token] -= debtToRepay;
                emit Repaid(token, toWithdraw, debtToRepay);
            }

            collateralBalances[token] -= toWithdraw;
            IERC20(token).safeTransfer(to, toWithdraw);
            emit Withdrawn(token, to, toWithdraw);
        }
    }

    function totalAssets() external view override returns (uint256) {
        uint256 totalUSD = 0;
        for (uint256 i = 0; i < supportedStocks.length; i++) {
            address token = supportedStocks[i];
            uint256 collateral = collateralBalances[token];
            if (collateral > 0) {
                uint256 stockPrice = oracle.getPrice(token);
                uint8 dec = getTokenDecimals(token);
                uint256 valUSD = (collateral * stockPrice) / (10 ** dec);

                uint256 debtUSDC = borrowedUSDC[token];
                uint256 yieldUSD = 0;
                if (debtUSDC > 0 && stableYieldStrategy != address(0)) {
                    uint256 initialUSDCUSD = debtUSDC * (10 ** (18 - getTokenDecimals(usdcToken)));
                    yieldUSD = (initialUSDCUSD * 6) / 100; // Simulated 6% APY yield
                }
                
                totalUSD += valUSD + yieldUSD;
            }
        }
        return totalUSD;
    }

    function harvest() external override onlyRouterOrVault {
        if (stableYieldStrategy != address(0)) {
            StableYieldStrategy(stableYieldStrategy).harvest();
        }
        emit Harvested(0);
    }

    function emergencyWithdraw() external override onlyRouterOrVault {
        for (uint256 i = 0; i < supportedStocks.length; i++) {
            address token = supportedStocks[i];
            uint256 collateral = collateralBalances[token];
            if (collateral > 0) {
                collateralBalances[token] = 0;
                borrowedUSDC[token] = 0;
                IERC20(token).safeTransfer(vault, collateral);
            }
        }
        emit EmergencyWithdrawExecuted();
    }
}

interface MockMintable {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
}
