// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseStrategy.sol";
import "../mocks/MockLendingMarket.sol";

contract StableYieldStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    MockLendingMarket public lendingMarket;
    address public usdcToken;

    constructor(
        address _strategyRouter,
        address _vault,
        address _oracle,
        address _lendingMarket,
        address _usdcToken
    ) BaseStrategy(_strategyRouter, _vault, _oracle) {
        lendingMarket = MockLendingMarket(_lendingMarket);
        usdcToken = _usdcToken;
        IERC20(_usdcToken).approve(_lendingMarket, type(uint256).max);
    }

    function deposit(address token, uint256 amount) external override onlyRouterOrVault {
        require(token == usdcToken, "StableYieldStrategy: only USDC supported");
        if (amount > 0) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            lendingMarket.deposit(token, amount);
            emit Deposited(token, amount);
        }
    }

    function withdraw(address token, address to, uint256 amount) external override onlyRouterOrVault {
        require(token == usdcToken, "StableYieldStrategy: only USDC supported");
        uint256 localBal = IERC20(token).balanceOf(address(this));
        if (localBal < amount) {
            uint256 needed = amount - localBal;
            uint256 marketBal = lendingMarket.balances(address(this), token);
            uint256 toWithdraw = needed > marketBal ? marketBal : needed;
            if (toWithdraw > 0) {
                lendingMarket.withdraw(token, toWithdraw);
            }
        }
        
        uint256 finalBal = IERC20(token).balanceOf(address(this));
        uint256 actualWithdraw = amount > finalBal ? finalBal : amount;
        if (actualWithdraw > 0) {
            IERC20(token).safeTransfer(to, actualWithdraw);
            emit Withdrawn(token, to, actualWithdraw);
        }
    }

    function totalAssets() external view override returns (uint256) {
        uint256 localBal = IERC20(usdcToken).balanceOf(address(this));
        uint256 marketBal = lendingMarket.balances(address(this), usdcToken);
        uint256 interest = lendingMarket.calculateInterest(address(this), usdcToken, marketBal);
        uint256 totalBal = localBal + marketBal + interest;

        if (totalBal > 0) {
            uint256 price = oracle.getPrice(usdcToken);
            uint8 dec = getTokenDecimals(usdcToken);
            return (totalBal * price) / (10 ** dec);
        }
        return 0;
    }

    function harvest() external override onlyRouterOrVault {
        uint256 marketBal = lendingMarket.balances(address(this), usdcToken);
        uint256 harvestUSD = 0;
        if (marketBal > 0) {
            uint256 interest = lendingMarket.calculateInterest(address(this), usdcToken, marketBal);
            if (interest > 0) {
                lendingMarket.withdraw(usdcToken, interest);
                lendingMarket.deposit(usdcToken, interest);
                
                uint256 price = oracle.getPrice(usdcToken);
                uint8 dec = getTokenDecimals(usdcToken);
                harvestUSD = (interest * price) / (10 ** dec);
            }
        }
        emit Harvested(harvestUSD);
    }

    function emergencyWithdraw() external override onlyRouterOrVault {
        uint256 marketBal = lendingMarket.balances(address(this), usdcToken);
        if (marketBal > 0) {
            lendingMarket.withdraw(usdcToken, marketBal);
        }
        uint256 bal = IERC20(usdcToken).balanceOf(address(this));
        if (bal > 0) {
            IERC20(usdcToken).safeTransfer(vault, bal);
        }
        emit EmergencyWithdrawExecuted();
    }
}
