// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseStrategy.sol";
import "../mocks/MockLendingMarket.sol";

contract LendingStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    MockLendingMarket public lendingMarket;
    address[] public tokens;
    mapping(address => bool) public isSupported;

    constructor(
        address _strategyRouter,
        address _vault,
        address _oracle,
        address _lendingMarket,
        address[] memory _tokens
    ) BaseStrategy(_strategyRouter, _vault, _oracle) {
        lendingMarket = MockLendingMarket(_lendingMarket);
        for (uint256 i = 0; i < _tokens.length; i++) {
            tokens.push(_tokens[i]);
            isSupported[_tokens[i]] = true;
            IERC20(_tokens[i]).approve(_lendingMarket, type(uint256).max);
        }
    }

    function deposit(address token, uint256 amount) external override onlyRouterOrVault {
        require(isSupported[token], "LendingStrategy: unsupported token");
        if (amount > 0) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            lendingMarket.deposit(token, amount);
            emit Deposited(token, amount);
        }
    }

    function withdraw(address token, address to, uint256 amount) external override onlyRouterOrVault {
        require(isSupported[token], "LendingStrategy: unsupported token");
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
        uint256 totalUSD = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 localBal = IERC20(token).balanceOf(address(this));
            uint256 marketBal = lendingMarket.balances(address(this), token);
            uint256 interest = lendingMarket.calculateInterest(address(this), token, marketBal);
            uint256 totalBal = localBal + marketBal + interest;

            if (totalBal > 0) {
                uint256 price = oracle.getPrice(token);
                uint8 dec = getTokenDecimals(token);
                totalUSD += (totalBal * price) / (10 ** dec);
            }
        }
        return totalUSD;
    }

    function harvest() external override onlyRouterOrVault {
        uint256 harvestUSD = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 marketBal = lendingMarket.balances(address(this), token);
            if (marketBal > 0) {
                uint256 interest = lendingMarket.calculateInterest(address(this), token, marketBal);
                if (interest > 0) {
                    lendingMarket.withdraw(token, interest);
                    lendingMarket.deposit(token, interest);
                    
                    uint256 price = oracle.getPrice(token);
                    uint8 dec = getTokenDecimals(token);
                    harvestUSD += (interest * price) / (10 ** dec);
                }
            }
        }
        emit Harvested(harvestUSD);
    }

    function emergencyWithdraw() external override onlyRouterOrVault {
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 marketBal = lendingMarket.balances(address(this), token);
            if (marketBal > 0) {
                lendingMarket.withdraw(token, marketBal);
            }
            uint256 bal = IERC20(token).balanceOf(address(this));
            if (bal > 0) {
                IERC20(token).safeTransfer(vault, bal);
            }
        }
        emit EmergencyWithdrawExecuted();
    }
}
